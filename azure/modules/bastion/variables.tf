#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#
variable "name_prefix" {
  description = "Prefix for resource names."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that holds the bastion."
  type        = string
}

variable "resource_group_id" {
  description = "Resource group ID, the scope of the login role assignments."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources."
  type        = map(string)
  default     = {}
}

variable "bastion_subnet_id" {
  description = "ID of the subnet named AzureBastionSubnet."
  type        = string
}

variable "sku" {
  description = "Bastion SKU. Developer is excluded: it has no subnet and is not for production."
  type        = string

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.sku)
    error_message = "sku must be Basic, Standard or Premium."
  }
}

variable "vm_ids" {
  description = "IDs of the VMs that get the Entra ID SSH login extension."
  type        = list(string)
}

variable "user_principal_ids" {
  description = "Object IDs granted Virtual Machine Administrator Login on the resource group."
  type        = list(string)
  default     = []
}
