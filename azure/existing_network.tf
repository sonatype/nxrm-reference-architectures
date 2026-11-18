#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

locals {
  subnet_id_pattern = "(?i)^(.*)/subnets/[^/]+$"
  subnet_id_parts   = "(?i)^/subscriptions/[^/]+/resourceGroups/([^/]+)/providers/Microsoft\\.Network/virtualNetworks/([^/]+)/subnets/([^/]+)$"

  # Module outputs when the template owns the network, the supplied ids otherwise.
  nodes_subnet_id   = try(module.network[0].nodes_subnet_id, var.nodes_subnet_id)
  db_subnet_id      = try(module.network[0].db_subnet_id, var.db_subnet_id)
  gateway_subnet_id = try(module.network[0].gateway_subnet_id, var.gateway_subnet_id)
  bastion_subnet_id = try(module.network[0].bastion_subnet_id, var.bastion_subnet_id)
  vnet_id           = try(module.network[0].vnet_id, regex(local.subnet_id_pattern, var.nodes_subnet_id)[0])

  # CIDRs the nodes allow on 8081 in gateway mode; read from the supplied subnets in an existing network.
  nodes_subnet_cidr   = var.create_network ? var.nodes_subnet_cidr : data.azurerm_subnet.nodes[0].address_prefixes[0]
  gateway_subnet_cidr = !local.use_gateway ? "" : var.create_network ? var.gateway_subnet_cidr : data.azurerm_subnet.gateway[0].address_prefixes[0]
}

# Read-only lookup of the customer's nodes subnet; nothing in it is created or changed.
data "azurerm_subnet" "nodes" {
  count                = var.create_network ? 0 : 1
  name                 = regex(local.subnet_id_parts, var.nodes_subnet_id)[2]
  virtual_network_name = regex(local.subnet_id_parts, var.nodes_subnet_id)[1]
  resource_group_name  = regex(local.subnet_id_parts, var.nodes_subnet_id)[0]
}

data "azurerm_subnet" "gateway" {
  count                = !var.create_network && local.use_gateway ? 1 : 0
  name                 = regex(local.subnet_id_parts, var.gateway_subnet_id)[2]
  virtual_network_name = regex(local.subnet_id_parts, var.gateway_subnet_id)[1]
  resource_group_name  = regex(local.subnet_id_parts, var.gateway_subnet_id)[0]
}

resource "terraform_data" "validate_existing_network" {
  count = var.create_network ? 0 : 1

  lifecycle {
    precondition {
      condition     = contains(data.azurerm_subnet.nodes[0].service_endpoints, "Microsoft.Storage")
      error_message = "The nodes subnet (nodes_subnet_id) needs the Microsoft.Storage service endpoint: add it to the subnet, or the storage firewall rejects the nodes."
    }

    precondition {
      condition     = local.use_gateway || contains(data.azurerm_subnet.nodes[0].service_endpoints, "Microsoft.KeyVault")
      error_message = "The nodes subnet (nodes_subnet_id) needs the Microsoft.KeyVault service endpoint on single nodes (nginx reads the certificate): add it to the subnet."
    }
  }
}
