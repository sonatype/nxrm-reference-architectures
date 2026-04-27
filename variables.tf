#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

# -----------------------------------------------------------------------------
# AWS Configuration
# -----------------------------------------------------------------------------

variable "aws_region" {
  description = "AWS region for all resources"
  type        = string
  default     = "us-east-1"
}

variable "environment_name" {
  description = "Name for this deployment (used in resource naming and tags)"
  type        = string
  default     = "nxrm"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment_name))
    error_message = "environment_name must contain only lowercase letters, numbers, and hyphens."
  }
}

variable "common_tags" {
  description = "Tags applied to all resources"
  type        = map(string)
  default     = {}
}

# -----------------------------------------------------------------------------
# NXRM Configuration
# -----------------------------------------------------------------------------

variable "nexus_admin_password" {
  description = "Admin password for Nexus Repository Manager. If not provided, a random 32-character password is generated. Retrieve with: terraform output -raw nexus_admin_password"
  type        = string
  sensitive   = true
  default     = null
}

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------

variable "create_vpc" {
  description = "Create a new VPC. Set to false to use an existing VPC."
  type        = bool
  default     = true
}

variable "vpc_id" {
  description = "Existing VPC ID (required when create_vpc = false)"
  type        = string
  default     = ""
}

variable "subnet_ids" {
  description = "Existing private subnet IDs across 2+ AZs (required when create_vpc = false)"
  type        = list(string)
  default     = []
}

variable "public_subnet_ids" {
  description = "Existing public subnet IDs for ALB across 2+ AZs (required when create_vpc = false). Falls back to subnet_ids if not provided."
  type        = list(string)
  default     = []
}

variable "vpc_cidr" {
  description = "CIDR block for new VPC (used when create_vpc = true)"
  type        = string
  default     = "10.0.0.0/16"
}

# -----------------------------------------------------------------------------
# Compute - Common
# -----------------------------------------------------------------------------

variable "cluster_size" {
  description = "Number of NXRM instances (1 for RA-1/RA-2, 3 for RA-3/RA-4, 4 for RA-5)"
  type        = number
  default     = 1

  validation {
    condition     = var.cluster_size >= 1 && var.cluster_size <= 10
    error_message = "cluster_size must be between 1 and 10."
  }
}

variable "instance_type" {
  description = "EC2 instance type for NXRM nodes"
  type        = string
  default     = "m8g.xlarge"
}

variable "instance_arch" {
  description = "Instance architecture: 'arm64' for Graviton or 'x86_64'"
  type        = string
  default     = "arm64"

  validation {
    condition     = contains(["arm64", "x86_64"], var.instance_arch)
    error_message = "instance_arch must be 'arm64' or 'x86_64'."
  }
}

# -----------------------------------------------------------------------------
# Database
# -----------------------------------------------------------------------------

variable "database_type" {
  description = "Database type: 'h2' for embedded (RA-1 only) or 'postgres' for RDS"
  type        = string
  default     = "postgres"

  validation {
    condition     = contains(["h2", "postgres"], var.database_type)
    error_message = "database_type must be 'h2' or 'postgres'."
  }
}

variable "db_instance_type" {
  description = "RDS PostgreSQL instance type"
  type        = string
  default     = "db.r8g.large"
}

variable "db_multi_az" {
  description = "Enable Multi-AZ for RDS (recommended for RA-3+)"
  type        = bool
  default     = false
}

variable "db_password" {
  description = "Master password for RDS PostgreSQL. Must be at least 16 characters. Use TF_VAR_db_password env var."
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = var.db_password == "" || length(var.db_password) >= 16
    error_message = "Database password must be at least 16 characters long."
  }
}

variable "db_engine_version" {
  description = "PostgreSQL engine version"
  type        = string
  default     = "16.6"
}

variable "db_allocated_storage" {
  description = "Allocated storage for RDS in GB"
  type        = number
  default     = 100
}

variable "db_max_connections" {
  description = "PostgreSQL max_connections parameter"
  type        = number
  default     = 500
}

variable "db_connection_pool" {
  description = "NXRM database connection pool size (maximumPoolSize)"
  type        = number
  default     = 100
}

# -----------------------------------------------------------------------------
# Storage
# -----------------------------------------------------------------------------

variable "blobstore_type" {
  description = "Blob store type: 's3' for S3 bucket or 'file' for local EBS volume"
  type        = string
  default     = "s3"

  validation {
    condition     = contains(["s3", "file"], var.blobstore_type)
    error_message = "blobstore_type must be 's3' or 'file'."
  }
}

variable "blobstore_force_destroy" {
  description = "Allow blobstore S3 bucket deletion even when non-empty. Set to true for dev/test, false for production."
  type        = bool
  default     = false
}

variable "blobstore_bucket_prefix" {
  description = "Prefix for S3 blob store bucket name (only used when blobstore_type = 's3')"
  type        = string
  default     = "nxrm-blobstore"
}

variable "nexus_blob_volume_size" {
  description = "Size of the EBS blob store volume in GB (only used when blobstore_type = 'file')"
  type        = number
  default     = 200
}

variable "nexus_blob_volume_type" {
  description = "EBS volume type for blob store: gp3, io1, io2 (only used when blobstore_type = 'file')"
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp3", "io1", "io2"], var.nexus_blob_volume_type)
    error_message = "nexus_blob_volume_type must be gp3, io1, or io2."
  }
}

variable "nexus_data_volume_size" {
  description = "Size of the EBS data volume in GB for NXRM operation (self-managed only)"
  type        = number
  default     = 200
}

variable "nexus_data_volume_type" {
  description = "EBS volume type for NXRM operation data: gp3, io1, io2"
  type        = string
  default     = "gp3"

  validation {
    condition     = contains(["gp3", "io1", "io2"], var.nexus_data_volume_type)
    error_message = "nexus_data_volume_type must be gp3, io1, or io2."
  }
}

# -----------------------------------------------------------------------------
# Load Balancer
# -----------------------------------------------------------------------------

variable "alb_certificate_arn" {
  description = "ACM certificate ARN for HTTPS on the ALB. If not provided, ALB will use HTTP only (not recommended for production)."
  type        = string
  default     = ""
}

variable "alb_internal" {
  description = "Whether the ALB is internal (true) or internet-facing (false)"
  type        = bool
  default     = false
}

variable "alb_ingress_cidr_blocks" {
  description = "CIDR blocks allowed to access the ALB on ports 80/443. Restrict to your corporate network for security."
  type        = list(string)
  default     = ["0.0.0.0/0"]
}

# -----------------------------------------------------------------------------
# JVM Settings
# -----------------------------------------------------------------------------

variable "java_min_heap" {
  description = "JVM minimum heap size (e.g., '8g')"
  type        = string
  default     = "8g"
}

variable "java_max_heap" {
  description = "JVM maximum heap size (e.g., '16g')"
  type        = string
  default     = "16g"
}

variable "java_max_direct_memory" {
  description = "JVM maximum direct memory (e.g., '8g')"
  type        = string
  default     = "8g"
}

# -----------------------------------------------------------------------------
# Installer Files
# -----------------------------------------------------------------------------

variable "installer_dir" {
  description = "Path to directory containing NXRM installer tarball and optional license file"
  type        = string
  default     = "files_to_upload_to_nodes"
}
