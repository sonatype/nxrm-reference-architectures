#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#
resource "azurerm_public_ip" "this" {
  name                = "${var.name_prefix}-bastion-pip"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = "Standard"
  allocation_method   = "Static"
  zones               = ["1", "2", "3"]
  tags                = var.tags
}

# Tunneling (az network bastion ssh) and file copy need Standard or Premium.
resource "azurerm_bastion_host" "this" {
  name                = "${var.name_prefix}-bastion"
  resource_group_name = var.resource_group_name
  location            = var.location
  sku                 = var.sku
  copy_paste_enabled  = true
  tunneling_enabled   = var.sku != "Basic"
  file_copy_enabled   = var.sku != "Basic"
  tags                = var.tags

  ip_configuration {
    name                 = "configuration"
    subnet_id            = var.bastion_subnet_id
    public_ip_address_id = azurerm_public_ip.this.id
  }
}

# Index keys keep for_each valid while the VM IDs are still unknown at plan time.
resource "azurerm_virtual_machine_extension" "aad_ssh" {
  for_each = toset([for i in range(length(var.vm_ids)) : tostring(i)])

  name                       = "AADSSHLoginForLinux"
  virtual_machine_id         = var.vm_ids[tonumber(each.key)]
  publisher                  = "Microsoft.Azure.ActiveDirectory"
  type                       = "AADSSHLoginForLinux"
  type_handler_version       = "1.0"
  auto_upgrade_minor_version = true
  tags                       = var.tags
}

resource "azurerm_role_assignment" "vm_login" {
  for_each = toset(var.user_principal_ids)

  scope                = var.resource_group_id
  role_definition_name = "Virtual Machine Administrator Login"
  principal_id         = each.value
}
