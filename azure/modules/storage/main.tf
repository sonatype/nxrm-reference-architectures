#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

locals {
  base_name = substr(replace(lower(var.name_prefix), "/[^a-z0-9]/", ""), 0, 14)

  # Azure rejects /32 in CIDR form, so single hosts are written as bare IPs.
  ip_rules = [for c in var.allowed_ip_cidrs : trimsuffix(c, "/32")]

  # Clients download through the SAS redirect, so the blob firewall follows the ingress CIDRs.
  blob_private = var.create_blob_account && var.use_private_endpoints

  blob_ip_rules = var.blob_default_action == "Allow" ? [] : [for c in var.blob_allowed_ip_cidrs : trimsuffix(c, "/32")]
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

# ---------- Artifacts (installer, license) ----------

resource "azurerm_storage_account" "artifacts" {
  name                            = "${local.base_name}a${random_string.suffix.result}"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = var.account_tier
  account_replication_type        = var.replication_type
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true
  tags                            = var.tags
}

resource "azurerm_storage_container" "artifacts" {
  name                  = "nxrm-assets"
  storage_account_id    = azurerm_storage_account.artifacts.id
  container_access_type = "private"
}

resource "azurerm_storage_blob" "tarball" {
  name                 = basename(var.tarball_path)
  storage_container_id = azurerm_storage_container.artifacts.id
  type                 = "Block"
  source               = var.tarball_path
  content_md5          = filemd5(var.tarball_path)
}

resource "azurerm_storage_blob" "license" {
  count                = var.license_path == "" ? 0 : 1
  name                 = basename(var.license_path)
  storage_container_id = azurerm_storage_container.artifacts.id
  type                 = "Block"
  source               = var.license_path
  content_md5          = filemd5(var.license_path)
}

# Firewall is closed only after the uploads, which need public access from the deployer.
resource "azurerm_storage_account_network_rules" "artifacts" {
  storage_account_id         = azurerm_storage_account.artifacts.id
  default_action             = "Deny"
  bypass                     = ["AzureServices"]
  ip_rules                   = local.ip_rules
  virtual_network_subnet_ids = [var.nodes_subnet_id]

  depends_on = [
    azurerm_storage_blob.tarball,
    azurerm_storage_blob.license,
  ]
}

resource "azurerm_role_assignment" "artifacts_reader" {
  scope                = azurerm_storage_account.artifacts.id
  role_definition_name = "Storage Blob Data Reader"
  principal_id         = var.identity_principal_id
  principal_type       = "ServicePrincipal"
}

# ---------- Nexus blob store (optional) ----------

resource "azurerm_storage_account" "blobs" {
  count                           = var.create_blob_account ? 1 : 0
  name                            = "${local.base_name}b${random_string.suffix.result}"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  account_tier                    = var.account_tier
  account_replication_type        = var.replication_type
  min_tls_version                 = "TLS1_2"
  allow_nested_items_to_be_public = false
  https_traffic_only_enabled      = true
  tags                            = var.tags

  # Private endpoint mode: reachable only through the endpoint (containers are created through Azure Resource Manager).
  public_network_access_enabled = !var.use_private_endpoints

  # Soft delete only: versioning, backups and protection against deleting the account are up to the customer.
  blob_properties {
    delete_retention_policy {
      days = 7
    }
    container_delete_retention_policy {
      days = 7
    }
  }

  # Keep Shared Key enabled: azurerm polls the data plane with it; disabling needs storage_use_azuread.
}

resource "azurerm_storage_container" "blobs" {
  count                 = var.create_blob_account ? 1 : 0
  name                  = "nxrm-blobs"
  storage_account_id    = azurerm_storage_account.blobs[0].id
  container_access_type = "private"
}

resource "azurerm_storage_account_network_rules" "blobs" {
  count                      = var.create_blob_account && !var.use_private_endpoints ? 1 : 0
  storage_account_id         = azurerm_storage_account.blobs[0].id
  default_action             = var.blob_default_action
  bypass                     = ["AzureServices"]
  ip_rules                   = local.blob_ip_rules
  virtual_network_subnet_ids = var.blob_default_action == "Deny" ? distinct(concat([var.nodes_subnet_id], var.blob_client_subnet_ids)) : [var.nodes_subnet_id]

  depends_on = [azurerm_storage_container.blobs]
}

resource "azurerm_role_assignment" "blobs_contributor" {
  count                = var.create_blob_account ? 1 : 0
  scope                = azurerm_storage_account.blobs[0].id
  role_definition_name = "Storage Blob Data Contributor"
  principal_id         = var.identity_principal_id
  principal_type       = "ServicePrincipal"
}

# ---------- Private endpoint for the Nexus blob store (optional) ----------

resource "azurerm_private_dns_zone" "blob" {
  count               = local.blob_private && var.blob_private_dns_zone_id == null ? 1 : 0
  name                = "privatelink.blob.core.windows.net"
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "blob" {
  count                 = local.blob_private && var.blob_private_dns_zone_id == null ? 1 : 0
  name                  = "${var.name_prefix}-blob-vnetlink"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.blob[0].name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false
  tags                  = var.tags
}

resource "azurerm_private_endpoint" "blob" {
  count               = local.blob_private ? 1 : 0
  name                = "${var.name_prefix}-blob-pe"
  resource_group_name = var.resource_group_name
  location            = var.location
  subnet_id           = var.nodes_subnet_id
  tags                = var.tags

  private_service_connection {
    name                           = "blob"
    private_connection_resource_id = azurerm_storage_account.blobs[0].id
    subresource_names              = ["blob"]
    is_manual_connection           = false
  }

  private_dns_zone_group {
    name                 = "blob"
    private_dns_zone_ids = [coalesce(var.blob_private_dns_zone_id, one(azurerm_private_dns_zone.blob[*].id))]
  }

  depends_on = [azurerm_private_dns_zone_virtual_network_link.blob]
}
