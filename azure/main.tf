#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

provider "azurerm" {
  features {}
  subscription_id = var.azure_subscription_id
}

locals {
  is_clustered = var.cluster_size > 1
  use_gateway  = local.is_clustered

  private_frontend = var.frontend_visibility == "private"
  name_prefix      = "nxrm-${var.environment_name}"
}

locals {
  tags = merge({
    project     = "nxrm-reference-architecture"
    environment = var.environment_name
    managed_by  = "terraform"
  }, var.common_tags)

  is_postgres = var.database_type == "postgres"

  # Direct Download redirects clients to the blob endpoint, so its firewall follows the ingress CIDRs.
  blob_firewall_open = contains(var.ingress_cidr_blocks, "0.0.0.0/0")

  # Storage firewalls reject private ranges; those clients use the subnet endpoint or a private endpoint.
  private_range_pattern = "^(10\\.[0-9.]+(/([89]|[12][0-9]|3[0-2]))?|172\\.(1[6-9]|2[0-9]|3[01])\\.[0-9.]+(/(1[2-9]|2[0-9]|3[0-2]))?|192\\.168\\.[0-9.]+(/(1[6-9]|2[0-9]|3[0-2]))?)$"
  blob_public_ingress   = [for c in var.ingress_cidr_blocks : c if !can(regex(local.private_range_pattern, c))]

  tarball_path = try("${path.root}/${var.installer_dir}/${one(local.installer_files)}", "")
  license_path = try("${path.root}/${var.installer_dir}/${one(local.license_files)}", "")
}

resource "azurerm_resource_group" "main" {
  name     = "${local.name_prefix}-rg"
  location = var.location
  tags     = local.tags
}

# ---------- Identities (the gateway has its own, with no access to passwords or storage) ----------

resource "azurerm_user_assigned_identity" "nexus" {
  name                = "${local.name_prefix}-identity"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  tags                = local.tags
}

resource "azurerm_user_assigned_identity" "gateway" {
  count               = local.use_gateway ? 1 : 0
  name                = "${local.name_prefix}-gateway-identity"
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  tags                = local.tags
}

locals {
  # The gateway reads the certificate on clusters; nginx on the node reads it on single nodes.
  certificate_reader_principal_id = local.use_gateway ? azurerm_user_assigned_identity.gateway[0].principal_id : azurerm_user_assigned_identity.nexus.principal_id

  certificate_secret_id      = trimsuffix(var.certificate_secret_id, "/")
  certificate_secret_name    = regex("/secrets/([^/]+)$", local.certificate_secret_id)[0]
  certificate_secret_vault   = lower(regex("^https://([^.]+)\\.", local.certificate_secret_id)[0])
  certificate_key_vault_name = lower(try(regex("/vaults/([^/]+)/?$", var.certificate_key_vault_id)[0], ""))
}

# Read access to the TLS certificate secret only, for the gateway (M/L/XL) or nginx on the node (XS/S).
resource "azurerm_role_assignment" "key_vault_secrets_user" {
  scope                = "${trimsuffix(var.certificate_key_vault_id, "/")}/secrets/${local.certificate_secret_name}"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = local.certificate_reader_principal_id
  principal_type       = "ServicePrincipal"

  lifecycle {
    precondition {
      condition     = local.certificate_key_vault_name != "" && local.certificate_key_vault_name == local.certificate_secret_vault
      error_message = "certificate_secret_id must point at the vault named in certificate_key_vault_id (/vaults/<name>)."
    }
  }
}

# ---------- Secrets ----------

resource "random_password" "nexus_admin" {
  count            = nonsensitive(var.nexus_admin_password == null) ? 1 : 0
  length           = 32
  special          = true
  override_special = "@*-_+."
}

resource "random_password" "db" {
  count            = local.is_postgres && nonsensitive(var.db_password == null) ? 1 : 0
  length           = 32
  special          = true
  override_special = "@*-_+."
}

locals {
  nexus_admin_password = var.nexus_admin_password != null ? var.nexus_admin_password : random_password.nexus_admin[0].result
  db_password          = !local.is_postgres ? "" : var.db_password != null ? var.db_password : random_password.db[0].result
}

# ---------- SSH key (generated only when none is supplied) ----------

resource "tls_private_key" "admin" {
  count     = var.admin_ssh_public_key == "" ? 1 : 0
  algorithm = "RSA"
  rsa_bits  = 4096
}

locals {
  admin_ssh_public_key = var.admin_ssh_public_key != "" ? var.admin_ssh_public_key : tls_private_key.admin[0].public_key_openssh
}

# ---------- Modules ----------

module "network" {
  source = "./modules/network"
  count  = var.create_network ? 1 : 0

  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  tags                = local.tags
  vnet_cidr           = var.vnet_cidr
  nodes_subnet_cidr   = var.nodes_subnet_cidr
  db_subnet_cidr      = var.db_subnet_cidr
  gateway_subnet_cidr = var.gateway_subnet_cidr
  use_gateway         = local.use_gateway
  create_db_subnet    = local.is_postgres
  ingress_cidr_blocks = var.ingress_cidr_blocks
  enable_bastion      = var.enable_bastion
  bastion_subnet_cidr = var.bastion_subnet_cidr
  private_frontend    = local.private_frontend
}

# Skipped when the installer preconditions fail, so filemd5 never sees a missing file.
module "storage" {
  source = "./modules/storage"

  name_prefix              = local.name_prefix
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  tags                     = local.tags
  tarball_path             = local.tarball_path
  license_path             = local.license_path
  create_blob_account      = var.blobstore_type == "azure"
  account_tier             = var.storage_account_tier
  replication_type         = var.storage_account_replication_type
  nodes_subnet_id          = local.nodes_subnet_id
  allowed_ip_cidrs         = local.storage_allowed_ips
  blob_default_action      = local.blob_firewall_open ? "Allow" : "Deny"
  blob_allowed_ip_cidrs    = local.blob_firewall_open ? [] : distinct(concat(local.blob_public_ingress, local.storage_allowed_ips))
  identity_principal_id    = azurerm_user_assigned_identity.nexus.principal_id
  use_private_endpoints    = var.use_private_endpoints
  blob_client_subnet_ids   = var.blob_client_subnet_ids
  vnet_id                  = local.vnet_id
  blob_private_dns_zone_id = var.blob_private_dns_zone_id

  depends_on = [terraform_data.validate_installer, terraform_data.validate_existing_network]
}

module "key_vault" {
  source = "./modules/key_vault"

  name_prefix                = local.name_prefix
  resource_group_name        = azurerm_resource_group.main.name
  location                   = var.location
  tags                       = local.tags
  nodes_subnet_id            = local.nodes_subnet_id
  allowed_ip_cidrs           = local.storage_allowed_ips
  node_identity_principal_id = azurerm_user_assigned_identity.nexus.principal_id
  admin_password             = local.nexus_admin_password
  create_db_secret           = local.is_postgres
  db_password                = local.db_password

  depends_on = [terraform_data.validate_existing_network]
}

module "postgres" {
  source = "./modules/postgres"
  count  = local.is_postgres ? 1 : 0

  name_prefix           = local.name_prefix
  resource_group_name   = azurerm_resource_group.main.name
  location              = var.location
  tags                  = local.tags
  delegated_subnet_id   = local.db_subnet_id
  vnet_id               = local.vnet_id
  private_dns_zone_id   = var.postgres_private_dns_zone_id
  sku_name              = var.postgres_sku_name
  storage_mb            = var.postgres_storage_mb
  pg_version            = var.postgres_version
  max_connections       = var.postgres_max_connections
  backup_retention_days = var.postgres_backup_retention_days
  zone                  = var.postgres_zone
  zone_redundant_ha     = var.postgres_zone_redundant_ha
  db_name               = var.db_name
  admin_login           = var.db_user
  admin_password        = local.db_password
}

module "cloud_init" {
  source = "./modules/cloud_init"

  cluster_size           = var.cluster_size
  artifacts_account      = module.storage.artifacts_account_name
  artifacts_container    = module.storage.artifacts_container
  tarball_blob           = module.storage.tarball_blob
  license_blob           = module.storage.license_blob
  key_vault_name         = module.key_vault.name
  admin_secret_name      = module.key_vault.admin_secret_name
  db_secret_name         = module.key_vault.db_secret_name
  identity_client_id     = azurerm_user_assigned_identity.nexus.client_id
  java_min_heap          = var.java_min_heap
  java_max_heap          = var.java_max_heap
  java_max_direct_memory = var.java_max_direct_memory
  clustered              = local.is_clustered
  database_type          = var.database_type
  db_host                = try(module.postgres[0].fqdn, "")
  db_name                = local.is_postgres ? module.postgres[0].db_name : ""
  db_user                = local.is_postgres ? var.db_user : ""
  nxrm_connection_pool   = var.nxrm_connection_pool
  blobstore_type         = var.blobstore_type
  blob_account           = module.storage.blob_account_name
  blob_container         = module.storage.blob_container
  tls_mode               = local.use_gateway ? "gateway" : "nginx"
  dns_name               = var.dns_name
  certificate_secret_id  = local.certificate_secret_id
  gateway_subnet_cidr    = local.gateway_subnet_cidr
  nodes_subnet_cidr      = local.nodes_subnet_cidr
}

module "compute" {
  source = "./modules/compute"

  name_prefix              = local.name_prefix
  resource_group_name      = azurerm_resource_group.main.name
  location                 = var.location
  tags                     = local.tags
  cluster_size             = var.cluster_size
  vm_size                  = var.vm_size
  image_publisher          = var.image_publisher
  image_offer              = var.image_offer
  image_sku                = var.image_sku
  image_version            = var.image_version
  os_disk_size_gb          = var.os_disk_size_gb
  data_disk_size_gb        = var.nexus_data_volume_size
  data_disk_type           = var.nexus_data_volume_type
  zone                     = var.zone
  subnet_id                = local.nodes_subnet_id
  subnet_cidr              = var.create_network ? var.nodes_subnet_cidr : null
  private_ips              = var.node_private_ips
  identity_id              = azurerm_user_assigned_identity.nexus.id
  system_assigned_identity = var.enable_bastion
  admin_username           = var.admin_username
  admin_ssh_public_key     = local.admin_ssh_public_key
  custom_data              = module.cloud_init.custom_data

  # Boot needs the certificate grant, the storage and Key Vault roles and firewalls, and a ready database.
  depends_on = [
    azurerm_role_assignment.key_vault_secrets_user,
    module.network,
    terraform_data.validate_existing_network,
    module.storage,
    module.key_vault,
    module.postgres,
  ]
}

module "public_lb" {
  source = "./modules/public_lb"
  count  = local.use_gateway ? 0 : 1

  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.main.name
  location            = var.location
  tags                = local.tags
  nic_ids             = module.compute.nic_ids
  private_frontend    = local.private_frontend
  subnet_id           = local.nodes_subnet_id
  private_ip_address  = var.private_frontend_ip
}

module "gateway" {
  source = "./modules/gateway"
  count  = local.use_gateway ? 1 : 0

  name_prefix             = local.name_prefix
  resource_group_name     = azurerm_resource_group.main.name
  location                = var.location
  tags                    = local.tags
  subnet_id               = local.gateway_subnet_id
  backend_ips             = module.compute.private_ips
  dns_name                = var.dns_name
  certificate_secret_id   = local.certificate_secret_id
  identity_id             = azurerm_user_assigned_identity.gateway[0].id
  min_capacity            = var.gateway_min_capacity
  request_timeout_seconds = var.gateway_request_timeout_seconds
  private_frontend        = local.private_frontend
  private_ip_address      = var.private_frontend_ip

  # The gateway reads the certificate while it is created.
  depends_on = [azurerm_role_assignment.key_vault_secrets_user]
}

module "bastion" {
  source = "./modules/bastion"
  count  = var.enable_bastion ? 1 : 0

  name_prefix         = local.name_prefix
  resource_group_name = azurerm_resource_group.main.name
  resource_group_id   = azurerm_resource_group.main.id
  location            = var.location
  tags                = local.tags
  bastion_subnet_id   = local.bastion_subnet_id
  sku                 = var.bastion_sku
  vm_ids              = module.compute.vm_ids
  user_principal_ids  = var.bastion_user_principal_ids
}

# ---------- Optional DNS record ----------

locals {
  front_end_public_ip = local.private_frontend ? null : one(concat(module.gateway[*].public_ip_address, module.public_lb[*].public_ip_address))
  private_frontend_ip = local.private_frontend ? one(concat(module.gateway[*].private_ip_address, module.public_lb[*].private_ip_address)) : null
}

# Record name is dns_name minus ".<dns_zone_name>" (nexus.example.com in example.com -> nexus).
resource "azurerm_dns_a_record" "nexus" {
  count               = var.dns_zone_name != "" ? 1 : 0
  name                = trimsuffix(var.dns_name, ".${var.dns_zone_name}")
  zone_name           = var.dns_zone_name
  resource_group_name = var.dns_zone_resource_group
  ttl                 = 300
  records             = [local.front_end_public_ip]
  tags                = local.tags

  lifecycle {
    precondition {
      condition     = endswith(var.dns_name, ".${var.dns_zone_name}")
      error_message = "dns_name must be a host inside dns_zone_name (for example nexus.example.com in example.com)."
    }

    precondition {
      condition     = var.dns_zone_resource_group != ""
      error_message = "Set dns_zone_resource_group to the resource group of dns_zone_name."
    }
  }
}
