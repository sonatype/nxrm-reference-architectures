#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

output "nxrm_url" {
  description = "URL of Nexus Repository"
  value       = "https://${var.dns_name}"
}

output "nexus_admin_password" {
  description = "Retrieve with: terraform output -raw nexus_admin_password"
  value       = local.nexus_admin_password
  sensitive   = true
}

output "front_end_public_ip" {
  description = "Public IP of the gateway (clusters) or load balancer (single node); point dns_name at it. Null with frontend_visibility = private"
  value       = local.front_end_public_ip
}

output "private_frontend_ip_address" {
  description = "Private IP of the gateway or internal load balancer, null with frontend_visibility = public"
  value       = local.private_frontend_ip
}

output "resource_group_name" {
  description = "Resource group that holds the deployment"
  value       = azurerm_resource_group.main.name
}

output "node_private_ips" {
  description = "Private IP addresses of the Nexus nodes"
  value       = module.compute.private_ips
}

output "database_fqdn" {
  description = "Private FQDN of the PostgreSQL server, null for H2"
  value       = one(module.postgres[*].fqdn)
}

output "artifacts_account_name" {
  description = "Storage account holding the installer, license and secrets"
  value       = module.storage.artifacts_account_name
}

output "generated_ssh_private_key" {
  description = "Generated SSH private key, null when admin_ssh_public_key is set. Retrieve with: terraform output -raw generated_ssh_private_key"
  value       = one(tls_private_key.admin[*].private_key_openssh)
  sensitive   = true
}
