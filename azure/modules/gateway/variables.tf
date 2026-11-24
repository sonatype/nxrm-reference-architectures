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
  description = "Resource group that holds the gateway."
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

variable "subnet_id" {
  description = "Dedicated gateway subnet ID."
  type        = string
}

variable "backend_ips" {
  description = "Private IP addresses of the Nexus nodes."
  type        = list(string)
}

variable "dns_name" {
  description = "Public host name served by the HTTPS listener."
  type        = string

  validation {
    condition     = length(trimspace(var.dns_name)) > 0
    error_message = "dns_name must not be empty."
  }
}

variable "certificate_secret_id" {
  description = "Key Vault secret ID (versionless allowed) of the TLS certificate."
  type        = string
}

variable "identity_id" {
  description = "User-assigned identity ID allowed to read the certificate secret."
  type        = string
}

variable "min_capacity" {
  description = "Minimum autoscale instance count (two or more for zone redundancy); each instance reserves 10 capacity units."
  type        = number
  default     = 2

  validation {
    condition     = var.min_capacity >= 2 && var.min_capacity <= 100 && floor(var.min_capacity) == var.min_capacity
    error_message = "min_capacity must be a whole number from 2 to 100: Azure accepts an Application Gateway autoscale minimum of 0 to 100 instances (the template needs 2 or more)."
  }
}

variable "request_timeout_seconds" {
  description = "Backend request timeout in seconds."
  type        = number
  default     = 900

  validation {
    condition     = var.request_timeout_seconds >= 1 && var.request_timeout_seconds <= 86400
    error_message = "request_timeout_seconds must be between 1 and 86400."
  }
}

variable "private_frontend" {
  description = "Attach the listeners to a private frontend address instead of the public IP."
  type        = bool
  default     = false
}

variable "private_ip_address" {
  description = "Static private frontend address in the gateway subnet (required when private_frontend is true)."
  type        = string
  default     = null

  validation {
    condition     = !var.private_frontend || var.private_ip_address != null
    error_message = "Set private_ip_address when private_frontend is true."
  }
}
