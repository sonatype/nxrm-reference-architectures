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
  description = "Blob store type: s3 or file"
  type        = string
  default     = "s3"
}

variable "blobstore_bucket_arn" {
  description = "ARN of the S3 blob store bucket (null when blobstore_type = file)"
  type        = string
  default     = null
  nullable    = true
}

variable "artifact_bucket_arn" {
  description = "ARN of S3 bucket containing deployment artifacts"
  type        = string
  default     = ""
}
