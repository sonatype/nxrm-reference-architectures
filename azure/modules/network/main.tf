#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

resource "azurerm_virtual_network" "main" {
  name                = "${var.name_prefix}-vnet"
  address_space       = [var.vnet_cidr]
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

resource "azurerm_subnet" "nodes" {
  name                 = "nodes"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.nodes_subnet_cidr]
  # KeyVault: nodes read their passwords (and nginx the certificate); the firewalled vaults allow this subnet.
  service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault"]
}

# Azure adds the Storage endpoint to a delegated subnet on its own; declaring it avoids plan drift.
resource "azurerm_subnet" "db" {
  count                = var.create_db_subnet ? 1 : 0
  name                 = "db"
  resource_group_name  = var.resource_group_name
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
  count                = var.use_gateway ? 1 : 0
  name                 = "gateway"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.gateway_subnet_cidr]
}

# Azure requires this exact subnet name for Bastion.
resource "azurerm_subnet" "bastion" {
  count                = var.enable_bastion ? 1 : 0
  name                 = "AzureBastionSubnet"
  resource_group_name  = var.resource_group_name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = [var.bastion_subnet_cidr]
}

# Outbound for the private nodes; two IPs give SNAT port headroom.
resource "azurerm_public_ip" "nat" {
  count               = 2
  name                = "${var.name_prefix}-nat-pip-${count.index + 1}"
  location            = var.location
  resource_group_name = var.resource_group_name
  allocation_method   = "Static"
  sku                 = "Standard"
  zones               = ["1"]
  tags                = var.tags
}

resource "azurerm_nat_gateway" "main" {
  name                    = "${var.name_prefix}-natgw"
  location                = var.location
  resource_group_name     = var.resource_group_name
  sku_name                = "Standard"
  idle_timeout_in_minutes = 4
  zones                   = ["1"]
  tags                    = var.tags
}

resource "azurerm_nat_gateway_public_ip_association" "main" {
  count                = 2
  nat_gateway_id       = azurerm_nat_gateway.main.id
  public_ip_address_id = azurerm_public_ip.nat[count.index].id
}

resource "azurerm_subnet_nat_gateway_association" "nodes" {
  subnet_id      = azurerm_subnet.nodes.id
  nat_gateway_id = azurerm_nat_gateway.main.id
}

resource "azurerm_network_security_group" "nodes" {
  name                = "${var.name_prefix}-nodes-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Inbound from the VNet is limited to these allows; DenyVnetInbound (4000) drops the rest.
resource "azurerm_network_security_rule" "nodes_intra_subnet" {
  name                        = "AllowNodesToNodes"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = var.nodes_subnet_cidr
  destination_address_prefix  = var.nodes_subnet_cidr
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nodes.name
}

# Private frontend: the ingress CIDRs stay the allow list, but sources tagged Internet never match.
resource "azurerm_network_security_rule" "nodes_deny_internet" {
  count                       = var.private_frontend && !var.use_gateway ? 1 : 0
  name                        = "DenyInternetWeb"
  priority                    = 105
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nodes.name
}

resource "azurerm_network_security_rule" "nodes_https_ingress" {
  count                       = var.use_gateway ? 0 : 1
  name                        = "AllowHttpsFromIngress"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.ingress_cidr_blocks
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nodes.name
}

resource "azurerm_network_security_rule" "nodes_http_ingress" {
  count                       = var.use_gateway ? 0 : 1
  name                        = "AllowHttpFromIngress"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefixes     = var.ingress_cidr_blocks
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nodes.name
}

resource "azurerm_network_security_rule" "nodes_from_gateway" {
  count                       = var.use_gateway ? 1 : 0
  name                        = "AllowGatewayTo8081"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "8081"
  source_address_prefix       = var.gateway_subnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
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
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nodes.name
}

# Shell access is Run Command or Bastion; SSH is open only from the AzureBastionSubnet.
resource "azurerm_network_security_rule" "nodes_ssh_bastion" {
  count                       = var.enable_bastion ? 1 : 0
  name                        = "AllowSshFromBastion"
  priority                    = 140
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = var.bastion_subnet_cidr
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nodes.name
}

# Overrides Azure's AllowVnetInBound (peered networks, VPN) for everything not allowed above.
resource "azurerm_network_security_rule" "nodes_deny_vnet" {
  name                        = "DenyVnetInbound"
  priority                    = 4000
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "VirtualNetwork"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.nodes.name
}

resource "azurerm_subnet_network_security_group_association" "nodes" {
  subnet_id                 = azurerm_subnet.nodes.id
  network_security_group_id = azurerm_network_security_group.nodes.id
}

resource "azurerm_network_security_group" "gateway" {
  count               = var.use_gateway ? 1 : 0
  name                = "${var.name_prefix}-gateway-nsg"
  location            = var.location
  resource_group_name = var.resource_group_name
  tags                = var.tags
}

# Application Gateway v2 management traffic; blocking it breaks the gateway.
resource "azurerm_network_security_rule" "gateway_manager" {
  count                       = var.use_gateway ? 1 : 0
  name                        = "AllowGatewayManager"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "65200-65535"
  source_address_prefix       = "GatewayManager"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.gateway[0].name
}

resource "azurerm_network_security_rule" "gateway_deny_internet" {
  count                       = var.private_frontend && var.use_gateway ? 1 : 0
  name                        = "DenyInternetWeb"
  priority                    = 105
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefix       = "Internet"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.gateway[0].name
}

resource "azurerm_network_security_rule" "gateway_https" {
  count                       = var.use_gateway ? 1 : 0
  name                        = "AllowHttpsFromIngress"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "443"
  source_address_prefixes     = var.ingress_cidr_blocks
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.gateway[0].name
}

resource "azurerm_network_security_rule" "gateway_http" {
  count                       = var.use_gateway ? 1 : 0
  name                        = "AllowHttpFromIngress"
  priority                    = 120
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "80"
  source_address_prefixes     = var.ingress_cidr_blocks
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.gateway[0].name
}

resource "azurerm_network_security_rule" "gateway_lb" {
  count                       = var.use_gateway ? 1 : 0
  name                        = "AllowAzureLoadBalancer"
  priority                    = 130
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "*"
  source_port_range           = "*"
  destination_port_range      = "*"
  source_address_prefix       = "AzureLoadBalancer"
  destination_address_prefix  = "*"
  resource_group_name         = var.resource_group_name
  network_security_group_name = azurerm_network_security_group.gateway[0].name
}

resource "azurerm_subnet_network_security_group_association" "gateway" {
  count                     = var.use_gateway ? 1 : 0
  subnet_id                 = azurerm_subnet.gateway[0].id
  network_security_group_id = azurerm_network_security_group.gateway[0].id
}
