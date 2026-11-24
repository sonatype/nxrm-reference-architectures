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
  description = "Resource group that holds the load balancer."
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

variable "nic_ids" {
  description = "Node network interface IDs added to the backend pool."
  type        = list(string)
}

variable "private_frontend" {
  description = "Use a private frontend address in subnet_id instead of a public IP."
  type        = bool
  default     = false
}

variable "subnet_id" {
  description = "Subnet that holds the private frontend address (used when private_frontend is true)."
  type        = string
  default     = null

  validation {
    condition     = !var.private_frontend || var.subnet_id != null
    error_message = "Set subnet_id when private_frontend is true."
  }
}

variable "private_ip_address" {
  description = "Static private frontend address; null lets Azure assign one."
  type        = string
  default     = null
}
