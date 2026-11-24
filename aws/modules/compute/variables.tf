#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

variable "name_prefix" {
  description = "Prefix for resource names"
  type        = string
}

variable "cluster_size" {
  description = "Number of EC2 instances to create"
  type        = number
}

variable "instance_type" {
  description = "EC2 instance type"
  type        = string
}

variable "instance_arch" {
  description = "Instance architecture: arm64 or x86_64"
  type        = string
}

variable "key_pair_id" {
  description = "SSH key pair ID"
  type        = string
}

variable "instance_profile_name" {
  description = "IAM instance profile name"
  type        = string
}

variable "vpc_id" {
  description = "VPC ID"
  type        = string
}

variable "subnet_ids" {
  description = "Subnet IDs for instance placement"
  type        = list(string)
}

variable "security_group_id" {
  description = "Security group ID for instances"
  type        = string
}

variable "artifact_bucket_name" {
  description = "S3 bucket name containing deployment artifacts (installer and optional license)"
  type        = string
}

variable "java_min_heap" {
  description = "JVM minimum heap size"
  type        = string
}

variable "java_max_heap" {
  description = "JVM maximum heap size"
  type        = string
}

variable "java_max_direct_memory" {
  description = "JVM maximum direct memory"
  type        = string
}

variable "blobstore_bucket" {
  description = "S3 bucket name for blob store"
  type        = string
}

variable "aws_region" {
  description = "AWS region for S3 blob store configuration"
  type        = string
}

variable "database_type" {
  description = "Database type: h2 or postgres"
  type        = string
}

variable "is_clustered" {
  description = "Whether this is a clustered deployment (RA-3+)"
  type        = bool
}

variable "ra_size" {
  description = "Reference Architecture size name (e.g., xsmall, small, medium, large, xlarge)"
  type        = string
  default     = "xsmall"
}

variable "rds_endpoint" {
  description = "RDS endpoint for PostgreSQL connection"
  type        = string
  default     = ""
}

variable "db_username" {
  description = "Database username"
  type        = string
  default     = "nxrm"
}

variable "db_password" {
  description = "Database password"
  type        = string
  sensitive   = true
  default     = ""
}

variable "db_connection_pool" {
  description = "Database connection pool size"
  type        = number
  default     = 100
}

variable "nexus_admin_password" {
  description = "Nexus admin password"
  type        = string
  sensitive   = true
}

variable "nexus_data_volume_size" {
  description = "Size of the EBS data volume in GB"
  type        = number
  default     = 200
}

variable "nexus_data_volume_type" {
  description = "EBS volume type for data volume"
  type        = string
  default     = "gp3"
}

variable "nexus_blob_volume_size" {
  description = "Size of the EBS blob storage volume in GB"
  type        = number
  default     = 200
}

variable "nexus_blob_volume_type" {
  description = "EBS volume type for blob storage volume"
  type        = string
  default     = "gp3"
}

variable "blobstore_type" {
  description = "Blob store type: 's3' or 'file'"
  type        = string
  default     = "s3"
}
