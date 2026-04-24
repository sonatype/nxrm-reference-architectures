# =============================================================================
# RA-4 (Large) - Self-Managed Configuration
# =============================================================================
# Use case: Large production with high throughput (1000-5000 users)
# Compute:  3x EC2 m8g.8xlarge (32 vCPU, 128 GiB RAM each)
# Database: RDS PostgreSQL db.r8g.4xlarge (Multi-AZ HA)
# Storage:  Single S3 bucket for blob store
# HA:       Yes (3-node Hazelcast cluster)
#
# Deploy with:
#   terraform apply -var-file=tfvars/ra-4-selfmanaged.tfvars
# =============================================================================

# -- General ------------------------------------------------------------------
environment_name = "nxrm-ra4"
aws_region       = "us-east-1"

# -- Networking (set create_vpc = false and provide IDs to use existing VPC) --
# create_vpc = false
# vpc_id     = "vpc-xxxxx"
# subnet_ids = ["subnet-aaaa", "subnet-bbbb"]

# -- HTTPS (required) ---------------------------------------------------------
# alb_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT:certificate/CERT_ID"

# -- Compute ------------------------------------------------------------------
instance_type = "m8g.8xlarge"
instance_arch = "arm64"
cluster_size  = 3

# -- JVM Settings -------------------------------------------------------------
java_min_heap          = "64g"
java_max_heap          = "64g"
java_max_direct_memory = "24g"

# -- Storage ------------------------------------------------------------------
nexus_data_volume_size = 500
nexus_data_volume_type = "gp3"

# -- Database -----------------------------------------------------------------
database_type        = "postgres"
db_instance_type     = "db.r8g.4xlarge"
db_multi_az          = true
db_engine_version    = "16.6"
db_allocated_storage = 500
db_max_connections   = 5000
db_connection_pool   = 200
# db_password        = "CHANGE_ME"  # Use env var TF_VAR_db_password or Secrets Manager
