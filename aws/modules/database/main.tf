#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

# modules/database/main.tf - RDS PostgreSQL for NXRM
# Supports single-instance (RA-2) and Multi-AZ HA (RA-3+)

locals {
  # Convert MB to 8kB pages for shared_buffers parameter
  shared_buffers_pages = var.shared_buffers_mb * 128

  postgres_family = "postgres${split(".", var.engine_version)[0]}"
}

###############################################################################
# Security Group
###############################################################################

resource "aws_security_group" "database" {
  name_prefix = "${var.environment_name}-nxrm-db-"
  description = "Security group for NXRM RDS PostgreSQL"
  vpc_id      = var.vpc_id

  tags = merge(var.tags, {
    Name = "${var.environment_name}-nxrm-db-sg"
  })

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_security_group_rule" "database_ingress" {
  count                    = length(var.allowed_security_group_ids)
  type                     = "ingress"
  from_port                = 5432
  to_port                  = 5432
  protocol                 = "tcp"
  source_security_group_id = var.allowed_security_group_ids[count.index]
  security_group_id        = aws_security_group.database.id
  description              = "PostgreSQL access from allowed security group"
}

###############################################################################
# Subnet Group
###############################################################################

resource "aws_db_subnet_group" "this" {
  name_prefix = "${var.environment_name}-nxrm-"
  subnet_ids  = var.subnet_ids

  tags = merge(var.tags, {
    Name = "${var.environment_name}-nxrm-db-subnet-group"
  })
}

###############################################################################
# Parameter Group
###############################################################################

resource "aws_db_parameter_group" "this" {
  name_prefix = "${var.environment_name}-nxrm-"
  family      = local.postgres_family

  parameter {
    name         = "max_connections"
    value        = var.max_connections
    apply_method = "pending-reboot"
  }

  parameter {
    name         = "shared_buffers"
    value        = local.shared_buffers_pages
    apply_method = "pending-reboot"
  }

  tags = merge(var.tags, {
    Name = "${var.environment_name}-nxrm-db-param-group"
  })

  lifecycle {
    create_before_destroy = true
  }
}

###############################################################################
# RDS Instance
###############################################################################

resource "aws_db_instance" "this" {
  identifier_prefix = "${var.environment_name}-nxrm-"

  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage = var.allocated_storage
  storage_type      = var.storage_type
  iops              = var.storage_iops

  db_name  = var.db_name
  username = var.db_username
  password = var.db_password

  db_subnet_group_name   = aws_db_subnet_group.this.name
  vpc_security_group_ids = [aws_security_group.database.id]
  parameter_group_name   = aws_db_parameter_group.this.name

  multi_az            = var.multi_az
  publicly_accessible = false

  backup_retention_period = var.backup_retention_period
  backup_window           = var.backup_window
  maintenance_window      = var.maintenance_window

  storage_encrypted   = true
  deletion_protection = var.deletion_protection
  skip_final_snapshot = !var.deletion_protection

  final_snapshot_identifier = var.deletion_protection ? "${var.environment_name}-nxrm-final-snapshot" : null

  tags = merge(var.tags, {
    Name = "${var.environment_name}-nxrm-db"
  })
}
