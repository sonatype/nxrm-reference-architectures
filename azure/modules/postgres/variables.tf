#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

variable "name_prefix" {
  description = "Prefix of the resource names"
  type        = string
}

variable "resource_group_name" {
  description = "Resource group that holds the database"
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

variable "delegated_subnet_id" {
  description = "Subnet delegated to Microsoft.DBforPostgreSQL/flexibleServers"
  type        = string
}

variable "vnet_id" {
  description = "Virtual network linked to the private DNS zone"
  type        = string
}

variable "sku_name" {
  description = "Flexible Server SKU, for example GP_Standard_D4ds_v5"
  type        = string
}

variable "storage_mb" {
  description = "Storage size in MB"
  type        = number
}

variable "pg_version" {
  description = "PostgreSQL major version"
  type        = string
}

variable "max_connections" {
  description = "max_connections server parameter; null leaves it unset. Never set it low."
  type        = number
  default     = null
}

variable "backup_retention_days" {
  description = "Backup retention in days (geo-redundant backup is not used)"
  type        = number
  default     = 7
}

variable "zone" {
  description = "Availability zone of the primary server"
  type        = string
  default     = "1"
}

variable "zone_redundant_ha" {
  description = "Enable zone-redundant high availability (optional, outside the tested configurations)"
  type        = bool
  default     = false
}

variable "db_name" {
  description = "Name of the Nexus database"
  type        = string
  default     = "nexus"
}

variable "admin_login" {
  description = "Administrator role; must equal the database user Nexus connects as"
  type        = string
}

variable "admin_password" {
  description = "Administrator password"
  type        = string
  sensitive   = true
}

variable "private_dns_zone_id" {
  description = "Existing private DNS zone for the server (null creates one and links the VNet)"
  type        = string
  default     = null

  validation {
    condition     = var.private_dns_zone_id == null || can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/privateDnsZones/[^/]+$", var.private_dns_zone_id))
    error_message = "private_dns_zone_id must be an Azure private DNS zone resource ID (/subscriptions/<id>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/<zone>)."
  }
}
