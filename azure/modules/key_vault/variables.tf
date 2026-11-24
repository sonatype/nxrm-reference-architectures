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
  description = "Resource group of the vault"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
}

variable "tags" {
  description = "Tags applied to the vault"
  type        = map(string)
  default     = {}
}

variable "nodes_subnet_id" {
  description = "Nodes subnet allowed on the vault firewall; it needs the Microsoft.KeyVault service endpoint"
  type        = string
}

variable "allowed_ip_cidrs" {
  description = "Public IPs or CIDRs of the machines that run Terraform, allowed on the vault firewall"
  type        = list(string)
  default     = []

  validation {
    condition     = !anytrue([for c in var.allowed_ip_cidrs : endswith(c, "/31")])
    error_message = "Key Vault does not accept /31 ranges; list single addresses or larger ranges."
  }
}

variable "node_identity_principal_id" {
  description = "Principal ID of the node identity that reads the secrets"
  type        = string
}

variable "admin_password" {
  description = "Nexus admin password"
  type        = string
  sensitive   = true
}

variable "create_db_secret" {
  description = "Store a database password (PostgreSQL deployments)"
  type        = bool
  default     = false
}

variable "db_password" {
  description = "Database password, used when create_db_secret is true"
  type        = string
  sensitive   = true
  default     = ""
}
