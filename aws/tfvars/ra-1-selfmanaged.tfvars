# =============================================================================
# RA-1 (XSmall) - Self-Managed Configuration
# =============================================================================
# Use case: Development environments, small teams (<50 users), CE edition
# Compute:  1x EC2 m8g.xlarge (4 vCPU, 16 GiB RAM)
# Database: H2 embedded (no RDS required)
# Storage:  Local EBS filesystem for blob store
# HA:       No (single instance)
#
# Prerequisites:
#   1. Place the NXRM installer tarball in files_to_upload_to_nodes/
#      (e.g., nexus-3.74.0-05-unix.tar.gz)
#   2. (Optional) Place a .lic file for Pro edition
#
# Deploy with:
#   terraform apply -var-file=tfvars/ra-1-selfmanaged.tfvars \
#     -var='alb_certificate_arn=arn:aws:acm:REGION:ACCOUNT:certificate/ID'
# =============================================================================

# =============================================================================
# REQUIRED - You must configure these for your environment
# =============================================================================

# AWS region where all resources will be created
aws_region = "us-east-1"

# ACM certificate ARN for HTTPS (must be in the same region as the deployment)
# Create one in AWS Certificate Manager before deploying:
#   https://docs.aws.amazon.com/acm/latest/userguide/gs-acm-request-public.html
# alb_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT:certificate/CERT_ID"

# =============================================================================
# NETWORKING - Choose one option
# =============================================================================
# Option A: Create a new VPC (default - no configuration needed)
# Option B: Use your existing VPC (uncomment and fill in below)

# create_vpc        = false
# vpc_id            = "vpc-xxxxxxxxxxxxxxxxx"
# subnet_ids        = ["subnet-aaaa", "subnet-bbbb"]   # Private subnets (2+ AZs) for EC2
# public_subnet_ids = ["subnet-cccc", "subnet-dddd"]   # Public subnets (2+ AZs) for ALB

# =============================================================================
# ALB Security - Restrict access for production environments
# =============================================================================
# alb_internal            = true                          # Internal ALB (no public internet access)
# alb_ingress_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12"]  # Corporate network CIDRs only

# =============================================================================
# OPTIONAL - Sensible defaults are pre-configured below
# =============================================================================

# -- General ------------------------------------------------------------------
environment_name = "nxrm-ra1"

# -- Compute ------------------------------------------------------------------
instance_type = "m8g.xlarge"
instance_arch = "arm64"
cluster_size  = 1

# -- JVM Settings (tuned for m8g.xlarge: 4 vCPU, 16 GiB) --------------------
java_min_heap          = "8g"
java_max_heap          = "8g"
java_max_direct_memory = "4g"

# -- Storage ------------------------------------------------------------------
blobstore_type         = "file"
nexus_data_volume_size = 200    # NXRM operation (sonatype-work, logs, db)
nexus_data_volume_type = "gp3"
nexus_blob_volume_size = 200    # NXRM blob storage (file blobstore)
nexus_blob_volume_type = "gp3"

# -- Database -----------------------------------------------------------------
database_type = "h2"

# -- Pro License (optional) ---------------------------------------------------
# Place a .lic file in files_to_upload_to_nodes/ to enable Pro features.

# -- PostgreSQL (set database_type = "postgres" to enable) --------------------
# db_instance_type    = "db.r8g.large"
# db_password         = ""   # Use TF_VAR_db_password env var instead
# db_allocated_storage = 100

# -- Tags (applied to all resources) ------------------------------------------
# common_tags = {
#   Team    = "platform"
#   CostCenter = "engineering"
# }
