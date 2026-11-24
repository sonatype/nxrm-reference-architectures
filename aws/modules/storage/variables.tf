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

variable "blobstore_type" {
  description = "Blob store type: 's3' for S3 bucket or 'file' for local EBS filesystem"
  type        = string
  default     = "s3"
}

variable "blobstore_bucket_prefix" {
  description = "Prefix for S3 blob store bucket name (used when blobstore_type = s3)"
  type        = string
}

variable "force_destroy" {
  description = "Allow bucket deletion even when non-empty (use with caution)"
  type        = bool
  default     = false
}
