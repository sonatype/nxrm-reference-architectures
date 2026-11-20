#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

output "instance_ids" {
  description = "EC2 instance IDs"
  value       = aws_instance.nxrm[*].id
}

output "instance_private_ips" {
  description = "Private IP addresses of NXRM instances"
  value       = aws_instance.nxrm[*].private_ip
}
