#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

output "nic_ids" {
  description = "Network interface IDs, one per node."
  value       = azurerm_network_interface.node[*].id
}

output "private_ips" {
  description = "Static private IP addresses, one per node."
  value       = [for nic in azurerm_network_interface.node : nic.private_ip_address]
}

output "vm_ids" {
  description = "Virtual machine IDs, one per node."
  value       = azurerm_linux_virtual_machine.node[*].id
}

output "identity_type" {
  description = "Managed identity type of the VMs (all nodes share it)."
  value       = azurerm_linux_virtual_machine.node[0].identity[0].type
}

output "nic_public_ip_address_ids" {
  description = "Public IP ID of each NIC ip_configuration, null when none (expected: all null)."
  value       = [for nic in azurerm_network_interface.node : nic.ip_configuration[0].public_ip_address_id]
}
