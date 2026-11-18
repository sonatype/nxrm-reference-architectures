#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

variable "create_vpc" {
  description = "Create a new VPC or use an existing one"
  type        = bool
}

variable "vpc_id" {
  description = "Existing VPC ID (used when create_vpc = false)"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Existing private subnet IDs for EC2 instances (used when create_vpc = false)"
  type        = list(string)
  default     = []
}

variable "public_subnet_ids" {
  description = "Existing public subnet IDs for ALB (used when create_vpc = false). Must be in at least 2 AZs."
  type        = list(string)
  default     = []
}

variable "vpc_cidr" {
  description = "CIDR block for new VPC (used when create_vpc = true)"
  type        = string
  default     = "10.0.0.0/16"
}

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "cluster_size" {
  description = "Number of NXRM instances"
  type        = number
}

variable "instance_type" {
  description = "EC2 instance type (used to filter AZs that support it)"
  type        = string
}
