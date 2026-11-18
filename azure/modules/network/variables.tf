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
  description = "Resource group that holds the network"
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

variable "vnet_cidr" {
  description = "Virtual network CIDR"
  type        = string
}

variable "nodes_subnet_cidr" {
  description = "Subnet CIDR of the Nexus nodes"
  type        = string
}

variable "db_subnet_cidr" {
  description = "Subnet CIDR of the PostgreSQL server"
  type        = string
}

variable "gateway_subnet_cidr" {
  description = "Subnet CIDR of the Application Gateway"
  type        = string
}

variable "use_gateway" {
  description = "Create the gateway subnet and route client traffic through the Application Gateway"
  type        = bool
}

variable "create_db_subnet" {
  description = "Create the delegated PostgreSQL subnet"
  type        = bool
}

variable "ingress_cidr_blocks" {
  description = "CIDR blocks allowed to reach the gateway or the nodes on 80/443"
  type        = list(string)
}

variable "bastion_subnet_cidr" {
  description = "Subnet CIDR of Azure Bastion (at least /26)"
  type        = string
  default     = ""
}

variable "enable_bastion" {
  description = "Create the AzureBastionSubnet"
  type        = bool
  default     = false
}

variable "private_frontend" {
  description = "Private frontend: deny Internet-tagged traffic on 80/443 ahead of the ingress allow rules"
  type        = bool
  default     = false
}
