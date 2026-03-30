#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

provider "aws" {
  region = var.aws_region

  default_tags {
    tags = merge(
      {
        Project     = "nxrm-reference-architecture"
        Environment = var.environment_name
        ManagedBy   = "terraform"
      },
      var.common_tags
    )
  }
}

# Generate random admin password if not provided
resource "random_password" "nexus_admin" {
  count   = var.nexus_admin_password == null ? 1 : 0
  length  = 32
  special = true
  # Only safest shell characters: @ * - _ + .
  override_special = "@*-_+."
}

locals {
  name_prefix  = "nxrm-${var.environment_name}"
  is_clustered = var.cluster_size > 1

  # Nexus admin password (user-provided or randomly generated)
  nexus_admin_password = coalesce(
    var.nexus_admin_password,
    try(random_password.nexus_admin[0].result, null)
  )

  # Installer file validation
  installer_files = fileset("${path.root}/${var.installer_dir}", "nexus*.tar.gz")
  license_files   = fileset("${path.root}/${var.installer_dir}", "*.lic")
  has_license     = length(local.license_files) > 0

  # Derive RA size name from instance type (used for logging in configure-nexus)
  ra_size = (
    var.instance_type == "m7g.xlarge" ? "xsmall" :
    var.instance_type == "m7g.2xlarge" && var.cluster_size == 1 ? "small" :
    var.instance_type == "m7g.2xlarge" ? "medium" :
    var.instance_type == "m7g.8xlarge" ? "large" :
    var.instance_type == "m7g.12xlarge" ? "xlarge" :
    "custom"
  )

  # Shorthand for conditionals
  uses_s3_blobs  = var.blobstore_type == "s3"
}

# -----------------------------------------------------------------------------
# Input Validation
# -----------------------------------------------------------------------------

resource "null_resource" "validate_installer" {
  lifecycle {
    precondition {
      condition     = length(local.installer_files) == 1
      error_message = "Place exactly one nexus*.tar.gz file in ${var.installer_dir}/ (e.g., nexus-3.90.2-unix.tar.gz)"
    }

    precondition {
      condition     = length(local.license_files) <= 1
      error_message = "Place at most one *.lic file in ${var.installer_dir}/ (optional - required for RA-2+)"
    }

    precondition {
      condition     = !local.is_clustered || local.has_license
      error_message = "A license file (*.lic) is required in ${var.installer_dir}/ for clustered deployments. Clustering requires NXRM Pro edition."
    }
  }
}

# -----------------------------------------------------------------------------
# SSH Key (for EC2 access)
# -----------------------------------------------------------------------------

resource "tls_private_key" "ssh_key" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

resource "aws_key_pair" "nxrm" {
  key_name_prefix = "${local.name_prefix}-"
  public_key      = tls_private_key.ssh_key.public_key_openssh
}

resource "local_sensitive_file" "ssh_private_key" {
  content         = tls_private_key.ssh_key.private_key_pem
  filename        = "${path.root}/${local.name_prefix}-ssh.pem"
  file_permission = "0400"
}

# -----------------------------------------------------------------------------
# Artifact S3 Bucket (upload local installer + license for EC2 provisioning)
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "artifacts" {
  bucket_prefix = "${local.name_prefix}-artifacts-"
  force_destroy = true
}

resource "aws_s3_bucket_server_side_encryption_configuration" "artifacts" {
  bucket = aws_s3_bucket.artifacts.id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "artifacts" {
  bucket                  = aws_s3_bucket.artifacts.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# Upload installer tarball
resource "aws_s3_object" "installer" {
  bucket = aws_s3_bucket.artifacts.id
  key    = "nxrm-assets/${element(tolist(local.installer_files), 0)}"
  source = "${path.root}/${var.installer_dir}/${element(tolist(local.installer_files), 0)}"
  etag   = filemd5("${path.root}/${var.installer_dir}/${element(tolist(local.installer_files), 0)}")

  depends_on = [null_resource.validate_installer]
}

# Upload license file (optional — required for RA-2+)
resource "aws_s3_object" "license" {
  count  = local.has_license ? 1 : 0
  bucket = aws_s3_bucket.artifacts.id
  key    = "nxrm-assets/${element(tolist(local.license_files), 0)}"
  source = "${path.root}/${var.installer_dir}/${element(tolist(local.license_files), 0)}"
  etag   = filemd5("${path.root}/${var.installer_dir}/${element(tolist(local.license_files), 0)}")
}

# -----------------------------------------------------------------------------
# Networking
# -----------------------------------------------------------------------------

module "networking" {
  source = "./modules/networking"

  create_vpc        = var.create_vpc
  vpc_id            = var.vpc_id
  subnet_ids        = var.subnet_ids
  public_subnet_ids = var.public_subnet_ids
  vpc_cidr          = var.vpc_cidr
  name_prefix       = local.name_prefix
  cluster_size      = var.cluster_size
  instance_type     = var.instance_type
}

# -----------------------------------------------------------------------------
# IAM
# -----------------------------------------------------------------------------

module "iam" {
  source = "./modules/iam"

  name_prefix          = local.name_prefix
  blobstore_type       = var.blobstore_type
  blobstore_bucket_arn = module.storage[0].bucket_arn
  artifact_bucket_arn  = aws_s3_bucket.artifacts.arn
}

# -----------------------------------------------------------------------------
# Storage (S3 Blob Store - only when blobstore_type = s3)
# -----------------------------------------------------------------------------

module "storage" {
  source = "./modules/storage"
  count  = var.blobstore_type == "s3" ? 1 : 0

  name_prefix             = local.name_prefix
  blobstore_type          = var.blobstore_type
  blobstore_bucket_prefix = var.blobstore_bucket_prefix
  force_destroy           = var.blobstore_force_destroy
}

# -----------------------------------------------------------------------------
# S3 Bucket Policy (only when blobstore_type = s3)
# Both storage.bucket_arn and iam.ec2_role_arn are available here.
# Only created when using S3 blobstore.
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "blobstore_bucket_policy" {
  count = local.uses_s3_blobs ? 1 : 0

  statement {
    sid = "NXRMBlobStoreAccess"
    actions = [
      "s3:GetObject",
      "s3:PutObject",
      "s3:DeleteObject",
      "s3:ListBucket",
      "s3:GetBucketLocation",
      "s3:GetLifecycleConfiguration",
      "s3:PutLifecycleConfiguration",
      "s3:ListBucketMultipartUploads",
      "s3:ListMultipartUploadParts",
      "s3:AbortMultipartUpload",
    ]
    resources = [
      module.storage[0].bucket_arn,
      "${module.storage[0].bucket_arn}/*",
    ]
    principals {
      type        = "AWS"
      identifiers = [module.iam.ec2_role_arn]
    }
  }
}

resource "aws_s3_bucket_policy" "blobstore" {
  count  = local.uses_s3_blobs ? 1 : 0
  bucket = module.storage[0].bucket_name
  policy = data.aws_iam_policy_document.blobstore_bucket_policy[0].json
}

# -----------------------------------------------------------------------------
# Database (RDS PostgreSQL - RA-2+)
# -----------------------------------------------------------------------------

module "database" {
  source = "./modules/database"
  count  = var.database_type == "postgres" ? 1 : 0

  environment_name           = local.name_prefix
  vpc_id                     = module.networking.vpc_id
  subnet_ids                 = module.networking.subnet_ids
  allowed_security_group_ids = [module.networking.nxrm_security_group_id]
  instance_class             = var.db_instance_type
  multi_az                   = var.db_multi_az
  db_password                = var.db_password
  engine_version             = var.db_engine_version
  allocated_storage          = var.db_allocated_storage
  max_connections            = var.db_max_connections
  deletion_protection        = false
}

# -----------------------------------------------------------------------------
# Load Balancer (ALB with HTTPS)
# -----------------------------------------------------------------------------

module "loadbalancer" {
  source = "./modules/loadbalancer"

  environment_name           = local.name_prefix
  vpc_id                     = module.networking.vpc_id
  subnet_ids                 = module.networking.public_subnet_ids
  certificate_arn            = var.alb_certificate_arn
  internal                   = var.alb_internal
  ingress_cidr_blocks        = var.alb_ingress_cidr_blocks
  enable_deletion_protection = false
}

# -----------------------------------------------------------------------------
# Target Group Attachment (EC2 instances -> ALB)
# -----------------------------------------------------------------------------

resource "aws_lb_target_group_attachment" "nxrm" {
  count            = var.cluster_size
  target_group_arn = module.loadbalancer.target_group_arn
  target_id        = module.compute.instance_ids[count.index]
  port             = 8081
}

# -----------------------------------------------------------------------------
# Compute (EC2 self-managed)
# -----------------------------------------------------------------------------

module "compute" {
  source = "./modules/compute"

  name_prefix            = local.name_prefix
  ra_size                = local.ra_size
  cluster_size           = var.cluster_size
  instance_type          = var.instance_type
  instance_arch          = var.instance_arch
  key_pair_id            = aws_key_pair.nxrm.id
  instance_profile_name  = module.iam.instance_profile_name
  vpc_id                 = module.networking.vpc_id
  subnet_ids             = module.networking.subnet_ids
  security_group_id      = module.networking.nxrm_security_group_id
  artifact_bucket_name   = aws_s3_bucket.artifacts.bucket
  java_min_heap          = var.java_min_heap
  java_max_heap          = var.java_max_heap
  java_max_direct_memory = var.java_max_direct_memory
  blobstore_type         = var.blobstore_type
  blobstore_bucket       = var.blobstore_type == "s3" ? module.storage[0].bucket_name : ""
  aws_region             = var.aws_region
  nexus_blob_volume_size = var.nexus_blob_volume_size
  nexus_blob_volume_type = var.nexus_blob_volume_type
  database_type          = var.database_type
  is_clustered           = local.is_clustered
  nexus_data_volume_size = var.nexus_data_volume_size
  nexus_data_volume_type = var.nexus_data_volume_type
  rds_endpoint           = var.database_type == "postgres" ? module.database[0].address : ""
  db_password            = var.db_password
  db_connection_pool     = var.db_connection_pool
  nexus_admin_password   = local.nexus_admin_password

  depends_on = [
    aws_s3_object.installer,
    aws_s3_object.license,
  ]
}
