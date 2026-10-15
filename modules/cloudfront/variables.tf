#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

variable "name" {
  description = "Name applied to the distribution's supporting resources. Must be unique within the account."
  type        = string
}

variable "bucket_name" {
  description = "Name of the S3 blob store bucket"
  type        = string
}

variable "bucket_regional_domain_name" {
  description = "Regional domain name of the S3 blob store bucket (origin)"
  type        = string
}

variable "default_ttl" {
  description = "Seconds CloudFront caches an object when S3 sends no Cache-Control header"
  type        = number
  default     = 86400
}

variable "max_ttl" {
  description = "Maximum seconds CloudFront caches an object, capping any Cache-Control from S3"
  type        = number
  default     = 7776000
}

variable "price_class" {
  description = "PriceClass_All, PriceClass_200, or PriceClass_100"
  type        = string
  default     = "PriceClass_All"
}

variable "enable_additional_metrics" {
  description = "Publish additional CloudWatch metrics (billed per metric per month; always in us-east-1)"
  type        = bool
  default     = true
}
