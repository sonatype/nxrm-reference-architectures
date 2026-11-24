#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

# A "customer-like" network: everything the Azure template needs, owned outside the template.

resource "azurerm_resource_group" "network" {
  name     = "${var.name_prefix}-rg"
  location = var.location
}

resource "azurerm_virtual_network" "main" {
  name                = "${var.name_prefix}-vnet"
  address_space       = [var.vnet_cidr]
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name
}

resource "azurerm_subnet" "nodes" {
  name                 = "nodes"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.nodes_subnet_cidr]
  # Storage: blob and installer access; KeyVault: nginx reads the certificate on single nodes.
  service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
}

# Empty and delegated; Azure adds the Storage endpoint itself, declaring it avoids drift.
resource "azurerm_subnet" "db" {
  name                 = "db"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.db_subnet_cidr]
  service_endpoints    = ["Microsoft.Storage"]

  delegation {
    name = "postgresql-flexible"
    service_delegation {
      name    = "Microsoft.DBforPostgreSQL/flexibleServers"
      actions = ["Microsoft.Network/virtualNetworks/subnets/join/action"]
    }
  }
}

resource "azurerm_subnet" "gateway" {
  name                 = "gateway"
  resource_group_name  = azurerm_resource_group.network.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.gateway_subnet_cidr]
}

# ---------- Outbound access for the nodes ----------

resource "azurerm_public_ip" "nat" {
  name                = "${var.name_prefix}-nat-pip"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]
}

resource "azurerm_nat_gateway" "main" {
  name                = "${var.name_prefix}-natgw"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name
  sku_name            = "Standard"
  zones               = ["1"]
}

resource "azurerm_nat_gateway_public_ip_association" "main" {
  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.nat.id
}

resource "azurerm_subnet_nat_gateway_association" "nodes" {
  subnet_id      = azurerm_subnet.nodes.id
  nat_gateway_id = azurerm_nat_gateway.main.id
}

# ---------- Nodes NSG ----------

resource "azurerm_network_security_group" "nodes" {
  name                = "${var.name_prefix}-nodes-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name
}

resource "azurerm_network_security_rule" "nodes_to_nodes" {
  name                        = "AllowNodesToNodes"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = var.nodes_subnet_cidr
  destination_address_prefix  = var.nodes_subnet_cidr
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.nodes.name
}

# Clustered sizes: the gateway reaches Nexus Repository on 8081.
resource "azurerm_network_security_rule" "nodes_from_gateway" {
  name                        = "AllowGatewayTo8081"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8081"
  source_address_prefix       = var.gateway_subnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.nodes.name
}

# Single-node sizes: clients reach nginx on the node through the load balancer.
resource "azurerm_network_security_rule" "nodes_web_from_clients" {
  name                        = "AllowWebFromClients"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefixes     = var.client_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.nodes.name
}

resource "azurerm_network_security_rule" "nodes_load_balancer" {
  name                        = "AllowAzureLoadBalancer"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.nodes.name
}

resource "azurerm_subnet_network_security_group_association" "nodes" {
  subnet_id                 = azurerm_subnet.nodes.id
  network_security_group_id = azurerm_network_security_group.nodes.id
}

# ---------- Gateway NSG ----------

resource "azurerm_network_security_group" "gateway" {
  name                = "${var.name_prefix}-gateway-nsg"
  location            = var.location
  resource_group_name = azurerm_resource_group.network.name
}

# Application Gateway v2 management traffic; blocking it breaks the gateway.
resource "azurerm_network_security_rule" "gateway_manager" {
  name                        = "AllowGatewayManager"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "65200-65535"
  source_address_prefix       = "GatewayManager"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.gateway.name
}

resource "azurerm_network_security_rule" "gateway_web_from_clients" {
  name                        = "AllowWebFromClients"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefixes     = var.client_cidrs
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.gateway.name
}

resource "azurerm_network_security_rule" "gateway_load_balancer" {
  name                        = "AllowAzureLoadBalancer"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = azurerm_resource_group.network.name
  network_security_group_name = azurerm_network_security_group.gateway.name
}

resource "azurerm_subnet_network_security_group_association" "gateway" {
  subnet_id                 = azurerm_subnet.gateway.id
  network_security_group_id = azurerm_network_security_group.gateway.id
}
