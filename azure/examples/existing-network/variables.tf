#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

variable "azure_subscription_id" {
  description = "Azure subscription ID that receives the example network"
  type        = string
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "name_prefix" {
  description = "Prefix of every resource name"
  type        = string
  default     = "nxrm-net"
}

variable "vnet_cidr" {
  description = "Virtual network CIDR"
  type        = string
  default     = "10.50.0.0/16"
}

variable "nodes_subnet_cidr" {
  description = "Subnet CIDR of the Nexus nodes"
  type        = string
  default     = "10.50.1.0/24"
}

variable "db_subnet_cidr" {
  description = "Subnet CIDR of PostgreSQL (empty, delegated)"
  type        = string
  default     = "10.50.3.0/24"
}

variable "gateway_subnet_cidr" {
  description = "Subnet CIDR of the Application Gateway (dedicated)"
  type        = string
  default     = "10.50.4.0/24"
}

variable "client_cidrs" {
  description = "Source ranges allowed to reach Nexus Repository on 80/443"
  type        = list(string)
  default     = ["0.0.0.0/0"]
}
