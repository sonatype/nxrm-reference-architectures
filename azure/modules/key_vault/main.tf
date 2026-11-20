#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

# Holds the generated admin and database passwords; nodes read them with the managed identity at boot.

data "azurerm_client_config" "current" {}

locals {
  base_name = substr(replace(lower(var.name_prefix), "/[^a-z0-9]/", ""), 0, 14)

  # Key Vault rejects /32 in CIDR form, so single hosts are written as bare IPs.
  ip_rules = [for c in var.allowed_ip_cidrs : trimsuffix(c, "/32")]
}

resource "random_string" "suffix" {
  length  = 6
  upper   = false
  special = false
}

resource "azurerm_key_vault" "main" {
  name                = "${local.base_name}kv${random_string.suffix.result}"
  resource_group_name = var.resource_group_name
  location            = var.location
  tenant_id           = data.azurerm_client_config.current.tenant_id
  sku_name            = "standard"
  tags                = var.tags

  rbac_authorization_enabled = true
  soft_delete_retention_days = 7
  purge_protection_enabled   = false

  # Closed to everything except the nodes subnet and the deployer addresses that write the secrets.
  # No trusted-service bypass: nothing else needs this vault.
  public_network_access_enabled = true
  network_acls {
    default_action             = "Deny"
    bypass                     = "None"
    ip_rules                   = local.ip_rules
    virtual_network_subnet_ids = [var.nodes_subnet_id]
  }
}

# The identity running Terraform writes the secrets, so it needs a data-plane role.
resource "azurerm_role_assignment" "deployer" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets Officer"
  principal_id         = data.azurerm_client_config.current.object_id
}

# A secret written before the role propagates is rejected with 403.
resource "time_sleep" "role_propagation" {
  create_duration = "90s"

  depends_on = [azurerm_role_assignment.deployer]
}

resource "azurerm_key_vault_secret" "admin" {
  name         = "nexus-admin-password"
  value        = var.admin_password
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"

  depends_on = [time_sleep.role_propagation]
}

resource "azurerm_key_vault_secret" "db" {
  count        = var.create_db_secret ? 1 : 0
  name         = "nexus-db-password"
  value        = var.db_password
  key_vault_id = azurerm_key_vault.main.id
  content_type = "text/plain"

  depends_on = [time_sleep.role_propagation]
}

# The node identity reads only these two secrets, not the whole vault.
resource "azurerm_role_assignment" "node_admin" {
  scope                = "${azurerm_key_vault.main.id}/secrets/${azurerm_key_vault_secret.admin.name}"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.node_identity_principal_id
  principal_type       = "ServicePrincipal"
}

resource "azurerm_role_assignment" "node_db" {
  count                = var.create_db_secret ? 1 : 0
  scope                = "${azurerm_key_vault.main.id}/secrets/${azurerm_key_vault_secret.db[0].name}"
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.node_identity_principal_id
  principal_type       = "ServicePrincipal"
}
