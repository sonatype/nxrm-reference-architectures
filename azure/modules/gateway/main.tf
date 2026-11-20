#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

locals {
  # Private mode: v2 keeps its public frontend for management, but listeners use only the private one.
  frontend_ip   = var.private_frontend ? "private" : "public"
  backend_pool  = "nodes"
  http_settings = "nexus-8081"
}

resource "azurerm_public_ip" "this" {
  name                = "${var.name_prefix}-gw-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  allocation_method   = "Static"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

resource "azurerm_application_gateway" "this" {
  name                = "${var.name_prefix}-gw"
  resource_group_name = var.resource_group_name
  location            = var.location
  zones               = ["1", "2", "3"]
  tags                = var.tags

  sku {
    name = "Standard_v2"
    tier = "Standard_v2"
  }

  autoscale_configuration {
    min_capacity = var.min_capacity
    max_capacity = 125
  }

  # The provider exposes this switch only in the global block.
  global {
    request_buffering_enabled  = false
    response_buffering_enabled = true
  }

  identity {
    type         = "UserAssigned"
    identity_ids = [var.identity_id]
  }

  gateway_ip_configuration {
    name      = "gateway-ip"
    subnet_id = var.subnet_id
  }

  frontend_ip_configuration {
    name                 = "public"
    public_ip_address_id = azurerm_public_ip.this.id
  }

  dynamic "frontend_ip_configuration" {
    for_each = var.private_frontend ? [1] : []
    content {
      name                          = "private"
      subnet_id                     = var.subnet_id
      private_ip_address            = var.private_ip_address
      private_ip_address_allocation = "Static"
    }
  }

  frontend_port {
    name = "port-80"
    port = 80
  }

  frontend_port {
    name = "port-443"
    port = 443
  }

  ssl_certificate {
    name                = "nexus"
    key_vault_secret_id = var.certificate_secret_id
  }

  ssl_policy {
    policy_type = "Predefined"
    policy_name = "AppGwSslPolicy20220101"
  }

  backend_address_pool {
    name         = local.backend_pool
    ip_addresses = var.backend_ips
  }

  # No host_name and no pick-host: Nexus sees the client's public host header.
  backend_http_settings {
    name                                = local.http_settings
    port                                = 8081
    protocol                            = "Http"
    request_timeout                     = var.request_timeout_seconds
    cookie_based_affinity               = "Enabled"
    pick_host_name_from_backend_address = false
    probe_name                          = "nexus-status"

    connection_draining {
      enabled           = true
      drain_timeout_sec = 900
    }
  }

  # Fixed Host so the probe works with any node IP and the public name.
  probe {
    name                                      = "nexus-status"
    protocol                                  = "Http"
    host                                      = "127.0.0.1"
    path                                      = "/service/rest/v1/status"
    interval                                  = 30
    timeout                                   = 30
    unhealthy_threshold                       = 3
    pick_host_name_from_backend_http_settings = false

    match {
      status_code = ["200"]
    }
  }

  http_listener {
    name                           = "https"
    frontend_ip_configuration_name = local.frontend_ip
    frontend_port_name             = "port-443"
    protocol                       = "Https"
    host_name                      = var.dns_name
    ssl_certificate_name           = "nexus"
  }

  http_listener {
    name                           = "http"
    frontend_ip_configuration_name = local.frontend_ip
    frontend_port_name             = "port-80"
    protocol                       = "Http"
    host_name                      = var.dns_name
  }

  redirect_configuration {
    name                 = "http-to-https"
    redirect_type        = "Permanent"
    target_listener_name = "https"
    include_path         = true
    include_query_string = true
  }

  request_routing_rule {
    name                       = "https-to-nodes"
    rule_type                  = "Basic"
    priority                   = 100
    http_listener_name         = "https"
    backend_address_pool_name  = local.backend_pool
    backend_http_settings_name = local.http_settings
  }

  request_routing_rule {
    name                        = "http-redirect"
    rule_type                   = "Basic"
    priority                    = 200
    http_listener_name          = "http"
    redirect_configuration_name = "http-to-https"
  }
}
