#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

output "bucket_name" {
  description = "S3 bucket name for NXRM blob store (empty when blobstore_type = file)"
  value       = var.blobstore_type == "s3" ? aws_s3_bucket.blobstore[0].id : ""
}

output "bucket_arn" {
  description = "S3 bucket ARN for NXRM blob store (empty when blobstore_type = file)"
  value       = var.blobstore_type == "s3" ? aws_s3_bucket.blobstore[0].arn : ""
}

output "bucket_region" {
  description = "S3 bucket region (empty when blobstore_type = file)"
  value       = var.blobstore_type == "s3" ? aws_s3_bucket.blobstore[0].region : ""
}
