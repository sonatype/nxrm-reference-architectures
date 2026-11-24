#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that holds the storage accounts"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}

variable "tarball_path" {
  description = "Local path of the Nexus installer tarball"
  type        = string
}

variable "license_path" {
  description = "Local path of the Nexus license file, empty for none"
  type        = string
  default     = ""
}

variable "create_blob_account" {
  description = "Create the storage account used as the Nexus blob store"
  type        = bool
}

variable "account_tier" {
  description = "Storage account tier"
  type        = string
  default     = "Standard"
}

variable "replication_type" {
  description = "Storage account replication type"
  type        = string
  default     = "LRS"
}

variable "nodes_subnet_id" {
  description = "Subnet of the Nexus nodes, allowed through the storage firewall"
  type        = string
}

variable "allowed_ip_cidrs" {
  description = "Public IPs or CIDRs allowed through the artifacts firewall"
  type        = list(string)
  default     = []

  validation {
    condition     = !anytrue([for c in var.allowed_ip_cidrs : endswith(c, "/31")])
    error_message = "Azure storage firewalls reject /31 ranges; use two single IPs instead."
  }
}

variable "identity_principal_id" {
  description = "Principal ID of the managed identity used by the Nexus nodes"
  type        = string
}

variable "blob_default_action" {
  description = "Default firewall action of the blob store account: Allow (open ingress) or Deny"
  type        = string
  default     = "Deny"

  validation {
    condition     = contains(["Allow", "Deny"], var.blob_default_action)
    error_message = "blob_default_action must be Allow or Deny."
  }
}

variable "blob_allowed_ip_cidrs" {
  description = "Public IPs or CIDRs allowed through the blob store firewall when it denies by default"
  type        = list(string)
  default     = []

  validation {
    condition     = !anytrue([for c in var.blob_allowed_ip_cidrs : endswith(c, "/31")])
    error_message = "Azure storage firewalls reject /31 ranges; use two single IPs instead."
  }
}

variable "use_private_endpoints" {
  description = "Reach the Nexus blob account only through a private endpoint in the nodes subnet (the artifacts account keeps its firewall)"
  type        = bool
  default     = false
}

variable "vnet_id" {
  description = "Virtual network linked to the blob private DNS zone (required with use_private_endpoints and no blob_private_dns_zone_id)"
  type        = string
  default     = null

  validation {
    condition     = !var.use_private_endpoints || var.blob_private_dns_zone_id != null || var.vnet_id != null
    error_message = "Set vnet_id (or blob_private_dns_zone_id) when use_private_endpoints is true."
  }
}

variable "blob_private_dns_zone_id" {
  description = "Existing privatelink.blob.core.windows.net zone (null creates one and links vnet_id)"
  type        = string
  default     = null

  validation {
    condition     = var.blob_private_dns_zone_id == null || can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/privateDnsZones/[^/]+$", var.blob_private_dns_zone_id))
    error_message = "blob_private_dns_zone_id must be an Azure private DNS zone resource ID."
  }
}

variable "blob_client_subnet_ids" {
  description = "Extra subnets allowed through the blob account firewall (Deny mode only); they need the Microsoft.Storage service endpoint"
  type        = list(string)
  default     = []
}
