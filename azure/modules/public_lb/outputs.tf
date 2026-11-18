#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

output "public_ip_address" {
  description = "Public IP address of the load balancer, null for a private frontend."
  value       = one(azurerm_public_ip.this[*].ip_address)
}

output "fqdn" {
  description = "FQDN of the public IP, null when no DNS label is set."
  value       = one(azurerm_public_ip.this[*].fqdn)
}

output "private_ip_address" {
  description = "Private frontend address, null for a public frontend."
  value       = var.private_frontend ? one(azurerm_lb.this.frontend_ip_configuration).private_ip_address : null
}
