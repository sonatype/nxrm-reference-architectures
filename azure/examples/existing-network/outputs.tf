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
  description = "Value for nodes_subnet_id"
  value       = azurerm_subnet.nodes.id
}

output "db_subnet_id" {
  description = "Value for db_subnet_id"
  value       = azurerm_subnet.db.id
}

output "gateway_subnet_id" {
  description = "Value for gateway_subnet_id"
  value       = azurerm_subnet.gateway.id
}

output "nodes_nsg_id" {
  description = "Network security group of the nodes subnet"
  value       = azurerm_network_security_group.nodes.id
}

output "gateway_nsg_id" {
  description = "Network security group of the gateway subnet"
  value       = azurerm_network_security_group.gateway.id
}
