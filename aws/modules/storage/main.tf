#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

# -----------------------------------------------------------------------------
# S3 Bucket for NXRM Blob Store (only when blobstore_type = s3)
# -----------------------------------------------------------------------------

resource "aws_s3_bucket" "blobstore" {
  count         = var.blobstore_type == "s3" ? 1 : 0
  bucket_prefix = "${var.blobstore_bucket_prefix}-"
  force_destroy = var.force_destroy

  tags = {
    Name = "${var.name_prefix}-blobstore"
  }
}

resource "aws_s3_bucket_versioning" "blobstore" {
  count  = var.blobstore_type == "s3" ? 1 : 0
  bucket = aws_s3_bucket.blobstore[0].id

  versioning_configuration {
    status = "Enabled"
  }
}

resource "aws_s3_bucket_server_side_encryption_configuration" "blobstore" {
  count  = var.blobstore_type == "s3" ? 1 : 0
  bucket = aws_s3_bucket.blobstore[0].id

  rule {
    apply_server_side_encryption_by_default {
      sse_algorithm = "AES256"
    }
  }
}

resource "aws_s3_bucket_public_access_block" "blobstore" {
  count  = var.blobstore_type == "s3" ? 1 : 0
  bucket = aws_s3_bucket.blobstore[0].id

  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# NOTE: S3 bucket policy is applied at the root module level to avoid
# circular dependency between storage and IAM modules.
