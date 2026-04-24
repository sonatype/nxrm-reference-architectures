# =============================================================================
# RA-2 (Small) - Self-Managed Configuration
# =============================================================================
# Use case: Small production deployments (50-200 users)
# Compute:  1x EC2 m8g.2xlarge (8 vCPU, 32 GiB RAM)
# Database: RDS PostgreSQL db.r8g.large (single instance)
# Storage:  Single S3 bucket for blob store
# HA:       No (single instance)
#
# Deploy with:
#   terraform apply -var-file=tfvars/ra-2-selfmanaged.tfvars
# =============================================================================

# -- General ------------------------------------------------------------------
environment_name = "nxrm-ra2"
aws_region       = "us-east-1"

# -- Networking (set create_vpc = false and provide IDs to use existing VPC) --
# create_vpc        = false
# vpc_id            = "vpc-xxxxx"
# subnet_ids        = ["subnet-private-aaaa", "subnet-private-bbbb"]
# public_subnet_ids = ["subnet-public-cccc", "subnet-public-dddd"]

# -- HTTPS (required) ---------------------------------------------------------
# alb_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT:certificate/CERT_ID"

# -- Compute ------------------------------------------------------------------
instance_type = "m8g.2xlarge"
instance_arch = "arm64"
cluster_size  = 1

# -- JVM Settings -------------------------------------------------------------
java_min_heap          = "16g"
java_max_heap          = "16g"
java_max_direct_memory = "8g"

# -- Storage ------------------------------------------------------------------
nexus_data_volume_size = 300
nexus_data_volume_type = "gp3"

# -- Database -----------------------------------------------------------------
database_type        = "postgres"
db_instance_type     = "db.r8g.large"
db_multi_az          = false
db_engine_version    = "16.6"
db_allocated_storage = 100
db_max_connections   = 1600
db_connection_pool   = 100
# IMPORTANT: Change this password before deploying to production. Use TF_VAR_db_password env var or Secrets Manager.
db_password = "CHANGE_ME"
