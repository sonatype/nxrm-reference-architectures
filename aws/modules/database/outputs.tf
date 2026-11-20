#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

output "endpoint" {
  description = "RDS instance endpoint (host:port)"
  value       = aws_db_instance.this.endpoint
}

output "address" {
  description = "RDS instance hostname"
  value       = aws_db_instance.this.address
}

output "port" {
  description = "RDS instance port"
  value       = aws_db_instance.this.port
}

output "db_name" {
  description = "Name of the database"
  value       = aws_db_instance.this.db_name
}

output "jdbc_url" {
  description = "JDBC connection string for NXRM configuration"
  value       = "jdbc:postgresql://${aws_db_instance.this.endpoint}/${aws_db_instance.this.db_name}"
}

output "security_group_id" {
  description = "Security group ID of the database"
  value       = aws_security_group.database.id
}
