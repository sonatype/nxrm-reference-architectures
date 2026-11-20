#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

# TLS terminates on the node (Nginx), so the LB passes TCP 80/443 through.
# A private frontend takes an address in the nodes subnet instead of a public IP.
resource "azurerm_public_ip" "this" {
  count               = var.private_frontend ? 0 : 1
  name                = "${var.name_prefix}-lb-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  allocation_method   = "Static"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_lb" "this" {
  name                = "${var.name_prefix}-lb"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  tags                = var.tags

  frontend_ip_configuration {
    name                          = "frontend"
    public_ip_address_id          = one(azurerm_public_ip.this[*].id)
    subnet_id                     = var.private_frontend ? var.subnet_id : null
    private_ip_address_allocation = var.private_frontend ? (var.private_ip_address == null ? "Dynamic" : "Static") : null
    private_ip_address            = var.private_frontend ? var.private_ip_address : null
  }
}

resource "azurerm_lb_backend_address_pool" "this" {
  name            = "nodes"
  loadbalancer_id = azurerm_lb.this.id
}

# Index keys keep for_each valid while the NIC IDs are still unknown at plan time.
resource "azurerm_network_interface_backend_address_pool_association" "node" {
  for_each = toset([for i in range(length(var.nic_ids)) : tostring(i)])

  network_interface_id    = var.nic_ids[tonumber(each.key)]
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.this.id
}

resource "azurerm_lb_probe" "https" {
  name                = "tcp-443"
  loadbalancer_id     = azurerm_lb.this.id
  protocol            = "Tcp"
  port                = 443
  interval_in_seconds = 5
  number_of_probes    = 2
}

# Outbound goes through the NAT gateway, so SNAT on the rules is disabled.
resource "azurerm_lb_rule" "http" {
  name                           = "http-80"
  loadbalancer_id                = azurerm_lb.this.id
  protocol                       = "Tcp"
  frontend_port                  = 80
  backend_port                   = 80
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.this.id]
  probe_id                       = azurerm_lb_probe.https.id
  idle_timeout_in_minutes        = 15
  tcp_reset_enabled              = true
  disable_outbound_snat          = true
}

resource "azurerm_lb_rule" "https" {
  name                           = "https-443"
  loadbalancer_id                = azurerm_lb.this.id
  protocol                       = "Tcp"
  frontend_port                  = 443
  backend_port                   = 443
  frontend_ip_configuration_name = "frontend"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.this.id]
  probe_id                       = azurerm_lb_probe.https.id
  idle_timeout_in_minutes        = 15
  tcp_reset_enabled              = true
  disable_outbound_snat          = true
}
