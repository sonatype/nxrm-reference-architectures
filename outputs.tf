#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------

output "vpc_id" {
  description = "VPC ID used by the deployment"
  value       = module.networking.vpc_id
}

output "subnet_ids" {
  description = "Subnet IDs used by the deployment"
  value       = module.networking.subnet_ids
}

# -----------------------------------------------------------------------------
# Storage
# -----------------------------------------------------------------------------

output "blobstore_bucket" {
  description = "S3 bucket name for NXRM blob store (empty when blobstore_type = file)"
  value       = module.storage[0].bucket_name
}

output "blobstore_type" {
  description = "Blob store type used by this deployment"
  value       = var.blobstore_type
}

# -----------------------------------------------------------------------------
# Compute (EC2)
# -----------------------------------------------------------------------------

output "instance_ids" {
  description = "EC2 instance IDs of NXRM instances"
  value       = module.compute.instance_ids
}

output "instance_ips" {
  description = "Private IP addresses of NXRM EC2 instances"
  value       = module.compute.instance_private_ips
}

output "ssh_key_path" {
  description = "Path to SSH private key for EC2 access"
  value       = local_sensitive_file.ssh_private_key.filename
}

# -----------------------------------------------------------------------------
# Load Balancer
# -----------------------------------------------------------------------------

output "nxrm_url" {
  description = "HTTPS URL to access NXRM via the ALB"
  value       = module.loadbalancer.nxrm_url
}

output "alb_dns_name" {
  description = "DNS name of the Application Load Balancer"
  value       = module.loadbalancer.alb_dns_name
}

# -----------------------------------------------------------------------------
# NXRM Configuration
# -----------------------------------------------------------------------------

output "nexus_admin_password" {
  description = "Admin password for Nexus Repository Manager. Retrieve with: terraform output -raw nexus_admin_password"
  value       = local.nexus_admin_password
  sensitive   = true
}

# -----------------------------------------------------------------------------
# Database
# -----------------------------------------------------------------------------

output "database_endpoint" {
  description = "RDS endpoint (when using PostgreSQL)"
  value       = var.database_type == "postgres" ? module.database[0].endpoint : null
}

