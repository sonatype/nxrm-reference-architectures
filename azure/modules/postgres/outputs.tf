#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

# Consumers (cloud-init) must not start before the database and server parameters exist.
output "fqdn" {
  description = "Private FQDN of the server, available once the database and parameters are applied"
  value       = azurerm_postgresql_flexible_server.main.fqdn

  depends_on = [
    azurerm_postgresql_flexible_server_database.main,
    azurerm_postgresql_flexible_server_configuration.azure_extensions,
    azurerm_postgresql_flexible_server_configuration.max_connections,
  ]
}

output "jdbc_url" {
  description = "JDBC URL without credentials"
  value       = "jdbc:postgresql://${azurerm_postgresql_flexible_server.main.fqdn}:5432/${azurerm_postgresql_flexible_server_database.main.name}"
}

output "db_name" {
  description = "Database name, available once the server parameters are applied"
  value       = azurerm_postgresql_flexible_server_database.main.name

  depends_on = [
    azurerm_postgresql_flexible_server_configuration.azure_extensions,
    azurerm_postgresql_flexible_server_configuration.max_connections,
  ]
}

output "admin_login" {
  description = "Administrator role (the Nexus db_user)"
  value       = azurerm_postgresql_flexible_server.main.administrator_login
}

output "private_dns_zone_id" {
  description = "Private DNS zone used by the server (the supplied one or the one created here)"
  value       = local.private_dns_zone_id
}
