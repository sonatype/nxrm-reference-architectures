#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

variable "name_prefix" {
  description = "Prefix for all resource names."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that holds the compute resources."
  type        = string
}

variable "location" {
  description = "Azure region."
  type        = string
}

variable "tags" {
  description = "Tags applied to every resource."
  type        = map(string)
  default     = {}
}

variable "cluster_size" {
  description = "Number of Nexus Repository nodes."
  type        = number

  validation {
    condition     = var.cluster_size >= 1
    error_message = "cluster_size must be at least 1."
  }
}

variable "vm_size" {
  description = "VM size of each node."
  type        = string
}

variable "image_publisher" {
  description = "Marketplace image publisher."
  type        = string
}

variable "image_offer" {
  description = "Marketplace image offer."
  type        = string
}

variable "image_sku" {
  description = "Marketplace image SKU."
  type        = string
}

variable "image_version" {
  description = "Marketplace image version."
  type        = string
  default     = "latest"
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB."
  type        = number
}

variable "data_disk_size_gb" {
  description = "Data disk size in GB."
  type        = number
}

variable "data_disk_type" {
  description = "Data disk storage account type (Premium_LRS or PremiumV2_LRS)."
  type        = string
}

variable "zone" {
  description = "Availability zone shared by the VMs and their data disks."
  type        = string
}

variable "subnet_id" {
  description = "Subnet that hosts the node NICs."
  type        = string
}

variable "subnet_cidr" {
  description = "CIDR of the node subnet, used for static NIC addresses; null with no private_ips gives dynamic addresses."
  type        = string
  default     = null
}

variable "private_ips" {
  description = "Static NIC addresses, one per node; null derives them from subnet_cidr or leaves them dynamic."
  type        = list(string)
  default     = null

  validation {
    condition     = var.private_ips == null ? true : length(var.private_ips) == var.cluster_size
    error_message = "private_ips must have one address per node (cluster_size)."
  }
}

variable "identity_id" {
  description = "Resource ID of the user-assigned managed identity."
  type        = string
}

variable "system_assigned_identity" {
  description = "Also enable a system-assigned identity (needed by Bastion)."
  type        = bool
  default     = false
}

variable "admin_username" {
  description = "Administrator user name."
  type        = string
}

variable "admin_ssh_public_key" {
  description = "SSH public key of the administrator."
  type        = string
}

variable "custom_data" {
  description = "Base64-encoded cloud-init payload, one element per node."
  type        = list(string)

  validation {
    condition     = length(var.custom_data) == var.cluster_size
    error_message = "custom_data must contain exactly one element per node (cluster_size)."
  }
}
