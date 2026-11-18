#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#
output "bastion_host_name" {
  description = "Name of the Bastion host."
  value       = azurerm_bastion_host.this.name
}

output "bastion_public_ip" {
  description = "Public IP address of the Bastion host."
  value       = azurerm_public_ip.this.ip_address
}
