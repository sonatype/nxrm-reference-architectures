#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

locals {
  create_dns_zone     = var.private_dns_zone_id == null
  private_dns_zone_id = coalesce(var.private_dns_zone_id, one(azurerm_private_dns_zone.postgres[*].id))
}

# Keeps the state of deployments created before the zone became optional.
moved {
  from = azurerm_private_dns_zone.postgres
  to   = azurerm_private_dns_zone.postgres[0]
}

moved {
  from = azurerm_private_dns_zone_virtual_network_link.postgres
  to   = azurerm_private_dns_zone_virtual_network_link.postgres[0]
}

# Zone and VNet link must exist before the server is created; a central zone replaces both.
resource "azurerm_private_dns_zone" "postgres" {
  count               = local.create_dns_zone ? 1 : 0
  name                = "privatelink.postgres.database.azure.com"
  resource_group_name = var.resource_group_name

  tags = var.tags
}

resource "azurerm_private_dns_zone_virtual_network_link" "postgres" {
  count                 = local.create_dns_zone ? 1 : 0
  name                  = "${var.name_prefix}-postgres-vnetlink"
  resource_group_name   = var.resource_group_name
  private_dns_zone_name = azurerm_private_dns_zone.postgres[0].name
  virtual_network_id    = var.vnet_id
  registration_enabled  = false

  tags = var.tags
}

# The server name is a global public DNS label, so it gets a random suffix.
resource "random_string" "suffix" {
  length  = 5
  upper   = false
  numeric = true
  special = false
}

resource "azurerm_postgresql_flexible_server" "main" {
  name                  = "${var.name_prefix}-postgres-${random_string.suffix.result}"
  resource_group_name   = var.resource_group_name
  location              = var.location
  version               = var.pg_version
  sku_name              = var.sku_name
  storage_mb            = var.storage_mb
  backup_retention_days = var.backup_retention_days
  zone                  = var.zone

  geo_redundant_backup_enabled = false

  # Must equal Nexus's db_user: it is the only role on a fresh server.
  administrator_login    = var.admin_login
  administrator_password = var.admin_password

  delegated_subnet_id           = var.delegated_subnet_id
  private_dns_zone_id           = local.private_dns_zone_id
  public_network_access_enabled = false

  dynamic "high_availability" {
    for_each = var.zone_redundant_ha ? [1] : []
    content {
      mode                      = "ZoneRedundant"
      standby_availability_zone = var.zone == "1" ? "2" : "1"
    }
  }

  tags = var.tags

  # Azure moves the primary and standby zones on failover.
  lifecycle {
    ignore_changes = [zone, high_availability[0].standby_availability_zone]
  }

  depends_on = [
    azurerm_private_dns_zone.postgres,
    azurerm_private_dns_zone_virtual_network_link.postgres,
  ]
}

resource "azurerm_postgresql_flexible_server_database" "main" {
  name      = var.db_name
  server_id = azurerm_postgresql_flexible_server.main.id
  charset   = "UTF8"
  collation = "en_US.utf8"
}

# Azure gates CREATE EXTENSION behind an allow-list; Flyway needs pg_trgm.
resource "azurerm_postgresql_flexible_server_configuration" "azure_extensions" {
  name      = "azure.extensions"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = "pg_trgm"
}

resource "azurerm_postgresql_flexible_server_configuration" "max_connections" {
  count = var.max_connections == null ? 0 : 1

  name      = "max_connections"
  server_id = azurerm_postgresql_flexible_server.main.id
  value     = tostring(var.max_connections)
}
