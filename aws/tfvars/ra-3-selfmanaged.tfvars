# =============================================================================
# RA-3 (Medium) - Self-Managed Configuration
# =============================================================================
# Use case: Medium production with HA (200-1000 users)
# Compute:  3x EC2 m8g.2xlarge (8 vCPU, 32 GiB RAM each)
# Database: RDS PostgreSQL db.r8g.2xlarge (Multi-AZ HA)
# Storage:  Single S3 bucket for blob store
# HA:       Yes (3-node Hazelcast cluster)
#
# Deploy with:
#   terraform apply -var-file=tfvars/ra-3-selfmanaged.tfvars
# =============================================================================

# -- General ------------------------------------------------------------------
environment_name = "nxrm-ra3"
aws_region       = "us-east-1"

# -- Networking (set create_vpc = false and provide IDs to use existing VPC) --
# create_vpc = false
# vpc_id     = "vpc-xxxxx"
# subnet_ids = ["subnet-aaaa", "subnet-bbbb"]

# -- HTTPS (required) ---------------------------------------------------------
# alb_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT:certificate/CERT_ID"

# -- Compute ------------------------------------------------------------------
instance_type = "m8g.2xlarge"
instance_arch = "arm64"
cluster_size  = 3

# -- JVM Settings -------------------------------------------------------------
java_min_heap          = "16g"
java_max_heap          = "16g"
java_max_direct_memory = "8g"

# -- Storage ------------------------------------------------------------------
blobstore_type         = "s3"
nexus_data_volume_size = 500
nexus_data_volume_type = "gp3"

# -- Database -----------------------------------------------------------------
database_type        = "postgres"
db_instance_type     = "db.r8g.2xlarge"
db_multi_az          = true
db_engine_version    = "16.6"
db_allocated_storage = 200
db_max_connections   = 5000
db_connection_pool   = 100
# db_password        = "CHANGE_ME"  # Use env var TF_VAR_db_password or Secrets Manager
