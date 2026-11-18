#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

variable "environment_name" {
  description = "Name prefix for all database resources"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID where the RDS instance will be created"
  type        = string
}

variable "subnet_ids" {
  description = "List of subnet IDs for the DB subnet group (minimum 2 in different AZs)"
  type        = list(string)

  validation {
    condition     = length(var.subnet_ids) >= 2
    error_message = "At least 2 subnet IDs in different availability zones are required for the DB subnet group."
  }
}

variable "allowed_security_group_ids" {
  description = "List of security group IDs allowed to connect to the database on port 5432"
  type        = list(string)
}

variable "instance_class" {
  description = "RDS instance class (e.g., db.r8g.large for RA-2, db.r8g.2xlarge for RA-3)"
  type        = string
}

variable "multi_az" {
  description = "Enable Multi-AZ deployment for high availability (required for RA-3+)"
  type        = bool
  default     = false
}

variable "db_name" {
  description = "Name of the PostgreSQL database to create"
  type        = string
  default     = "nxrm"
}

variable "db_username" {
  description = "Master username for the database"
  type        = string
  default     = "nxrm"
}

variable "db_password" {
  description = "Master password for the database. Must be at least 16 characters."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.db_password) >= 16
    error_message = "Database password must be at least 16 characters long."
  }
}

variable "engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.6"
}

variable "allocated_storage" {
  description = "Allocated storage in GB"
  type        = number
  default     = 100
}

variable "storage_type" {
  description = "Storage type (gp3, io1, io2)"
  type        = string
  default     = "gp3"
}

variable "storage_iops" {
  description = "Provisioned IOPS (only for io1/io2 storage types; null for gp3)"
  type        = number
  default     = null
}

variable "max_connections" {
  description = "PostgreSQL max_connections parameter"
  type        = number
  default     = 500
}

variable "shared_buffers_mb" {
  description = "PostgreSQL shared_buffers in MB (converted to 8kB pages internally)"
  type        = number
  default     = 4096
}

variable "backup_retention_period" {
  description = "Number of days to retain automated backups (0 to disable)"
  type        = number
  default     = 7
}

variable "backup_window" {
  description = "Preferred backup window (UTC)"
  type        = string
  default     = "03:00-04:00"
}

variable "maintenance_window" {
  description = "Preferred maintenance window (UTC)"
  type        = string
  default     = "sun:04:00-sun:05:00"
}

variable "deletion_protection" {
  description = "Enable deletion protection on the RDS instance"
  type        = bool
  default     = true
}

variable "tags" {
  description = "Tags to apply to all database resources"
  type        = map(string)
  default     = {}
}
