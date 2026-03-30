# =============================================================================
# RA-5 (XLarge) - Self-Managed Configuration
# =============================================================================
# Use case: Enterprise-scale deployments (5000+ users)
# Compute:  4x EC2 m7g.12xlarge (48 vCPU, 192 GiB RAM each)
# Database: RDS PostgreSQL db.r7g.8xlarge (Multi-AZ HA)
# Storage:  Single S3 bucket for blob store
# HA:       Yes (4-node Hazelcast cluster)
#
# Deploy with:
#   terraform apply -var-file=tfvars/ra-5-selfmanaged.tfvars
# =============================================================================

# -- General ------------------------------------------------------------------
environment_name = "nxrm-ra5"
aws_region       = "us-east-1"

# -- Networking (set create_vpc = false and provide IDs to use existing VPC) --
# create_vpc = false
# vpc_id     = "vpc-xxxxx"
# subnet_ids = ["subnet-aaaa", "subnet-bbbb"]

# -- HTTPS (required) ---------------------------------------------------------
# alb_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT:certificate/CERT_ID"

# -- Compute ------------------------------------------------------------------
instance_type = "m7g.12xlarge"
instance_arch = "arm64"
cluster_size  = 4

# -- JVM Settings -------------------------------------------------------------
java_min_heap          = "96g"
java_max_heap          = "96g"
java_max_direct_memory = "48g"

# -- Storage ------------------------------------------------------------------
blobstore_type         = "s3"
nexus_data_volume_size = 500
nexus_data_volume_type = "gp3"

# -- Database -----------------------------------------------------------------
database_type        = "postgres"
db_instance_type     = "db.r7g.8xlarge"
db_multi_az          = true
db_engine_version    = "16.6"
db_allocated_storage = 1000
db_max_connections   = 5000
db_connection_pool   = 800
# db_password        = "CHANGE_ME"  # Use env var TF_VAR_db_password or Secrets Manager
