#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

output "name" {
  description = "Name of the vault holding the Nexus secrets"
  value       = azurerm_key_vault.main.name
}

output "admin_secret_name" {
  description = "Secret holding the Nexus admin password"
  value       = azurerm_key_vault_secret.admin.name
}

output "db_secret_name" {
  description = "Secret holding the database password, empty when there is none"
  value       = var.create_db_secret ? azurerm_key_vault_secret.db[0].name : ""
}
