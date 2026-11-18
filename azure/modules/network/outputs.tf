#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

output "vnet_id" {
  description = "Virtual network ID"
  value       = azurerm_virtual_network.main.id
}

output "nodes_subnet_id" {
  description = "Nodes subnet ID"
  value       = azurerm_subnet.nodes.id
}

output "db_subnet_id" {
  description = "PostgreSQL delegated subnet ID, null when not created"
  value       = var.create_db_subnet ? azurerm_subnet.db[0].id : null
}

output "gateway_subnet_id" {
  description = "Application Gateway subnet ID, null without the gateway"
  value       = var.use_gateway ? azurerm_subnet.gateway[0].id : null
}

output "bastion_subnet_id" {
  description = "AzureBastionSubnet ID, null when Bastion is disabled"
  value       = var.enable_bastion ? azurerm_subnet.bastion[0].id : null
}

output "nat_public_ip_addresses" {
  description = "Outbound public IPs of the NAT gateway"
  value       = azurerm_public_ip.nat[*].ip_address
}
