#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

output "vpc_id" {
  description = "VPC ID"
  value       = local.vpc_id
}

output "subnet_ids" {
  description = "Private subnet IDs"
  value       = local.subnet_ids
}

output "public_subnet_ids" {
  description = "Public subnet IDs (for ALB)"
  value       = var.create_vpc ? aws_subnet.public[*].id : coalescelist(var.public_subnet_ids, var.subnet_ids)
}

output "nxrm_security_group_id" {
  description = "Security group ID for NXRM instances"
  value       = aws_security_group.nxrm.id
}


# NOTE: ALB security group is owned by the loadbalancer module.


# NOTE: Database security group is owned by the database module.
# The database module creates its own SG and accepts allowed_security_group_ids as input.
