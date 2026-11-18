#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

output "artifacts_account_name" {
  description = "Storage account holding the installer, license and secrets"
  value       = azurerm_storage_account.artifacts.name
}

output "artifacts_container" {
  description = "Container holding the installer, license and secrets"
  value       = azurerm_storage_container.artifacts.name
}

output "tarball_blob" {
  description = "Blob name of the Nexus installer"
  value       = azurerm_storage_blob.tarball.name
}

output "license_blob" {
  description = "Blob name of the license, empty when none"
  value       = var.license_path == "" ? "" : azurerm_storage_blob.license[0].name
}

output "secrets_blob" {
  description = "Blob name of the secrets document"
  value       = azurerm_storage_blob.secrets.name
}

output "blob_account_name" {
  description = "Storage account used as the Nexus blob store, null when not created"
  value       = var.create_blob_account ? azurerm_storage_account.blobs[0].name : null
}

output "blob_container" {
  description = "Container used as the Nexus blob store"
  value       = "nxrm-blobs"
}

output "blob_firewall" {
  description = "Firewall of the blob store account (default_action, ip_rules), null when not created or when a private endpoint is used"
  value = length(azurerm_storage_account_network_rules.blobs) == 1 ? {
    default_action = azurerm_storage_account_network_rules.blobs[0].default_action
    ip_rules       = azurerm_storage_account_network_rules.blobs[0].ip_rules
    subnet_ids     = azurerm_storage_account_network_rules.blobs[0].virtual_network_subnet_ids
  } : null
}
