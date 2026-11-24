#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

locals {
  # Supplied list wins, then cidrhost(subnet_cidr, 10 + i), otherwise Azure assigns the address.
  node_ips = [for i in range(var.cluster_size) : var.private_ips != null ? var.private_ips[i] : var.subnet_cidr != null ? cidrhost(var.subnet_cidr, 10 + i) : null]
}

resource "azurerm_network_interface" "node" {
  count = var.cluster_size

  name                           = "${var.name_prefix}-nic-${count.index}"
  location                       = var.location
  resource_group_name            = var.resource_group_name
  accelerated_networking_enabled = true

  ip_configuration {
    name                          = "internal"
    subnet_id                     = var.subnet_id
    private_ip_address_allocation = local.node_ips[count.index] == null ? "Dynamic" : "Static"
    private_ip_address            = local.node_ips[count.index]
  }

  tags = var.tags
}

resource "azurerm_managed_disk" "data" {
  count = var.cluster_size

  name                 = "${var.name_prefix}-data-${count.index}"
  location             = var.location
  resource_group_name  = var.resource_group_name
  storage_account_type = var.data_disk_type
  create_option        = "Empty"
  disk_size_gb         = var.data_disk_size_gb
  # A zonal VM can only attach a disk in its own zone.
  zone = var.zone

  tags = var.tags
}

resource "azurerm_linux_virtual_machine" "node" {
  count = var.cluster_size

  name                            = "${var.name_prefix}-node-${count.index}"
  resource_group_name             = var.resource_group_name
  location                        = var.location
  size                            = var.vm_size
  zone                            = var.zone
  admin_username                  = var.admin_username
  disable_password_authentication = true
  network_interface_ids           = [azurerm_network_interface.node[count.index].id]
  custom_data                     = var.custom_data[count.index]

  admin_ssh_key {
    username   = var.admin_username
    public_key = var.admin_ssh_public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
    disk_size_gb         = var.os_disk_size_gb
  }

  source_image_reference {
    publisher = var.image_publisher
    offer     = var.image_offer
    sku       = var.image_sku
    version   = var.image_version
  }

  identity {
    type         = var.system_assigned_identity ? "SystemAssigned, UserAssigned" : "UserAssigned"
    identity_ids = [var.identity_id]
  }

  boot_diagnostics {}

  tags = var.tags
}

# The attachment starts after the VM; cloud-init waits up to 900 s for LUN 0.
resource "azurerm_virtual_machine_data_disk_attachment" "data" {
  count = var.cluster_size

  managed_disk_id    = azurerm_managed_disk.data[count.index].id
  virtual_machine_id = azurerm_linux_virtual_machine.node[count.index].id
  lun                = 0
  # Premium SSD v2 rejects host caching.
  caching = var.data_disk_type == "PremiumV2_LRS" ? "None" : "ReadOnly"
}
