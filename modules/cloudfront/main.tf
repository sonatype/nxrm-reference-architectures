#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

# CloudFront distribution serving the S3 blob store through signed URLs.
# Nexus holds the private signing key; CloudFront verifies it at the edge.
# The bucket policy grant for the distribution lives in the root module.

# NOTE: the private key is stored in Terraform state. Use an encrypted remote backend.
resource "tls_private_key" "signing" {
  algorithm = "RSA"
  rsa_bits  = 2048
}

# A public key still referenced by a key group cannot be deleted, so the
# replacement must exist before the old one goes.
resource "aws_cloudfront_public_key" "signing" {
  name_prefix = "${var.name}-"
  encoded_key = tls_private_key.signing.public_key_pem
  comment     = "Signed-URL verification key for ${var.name}"

  lifecycle {
    create_before_destroy = true
  }
}

resource "aws_cloudfront_key_group" "signing" {
  name    = var.name
  items   = [aws_cloudfront_public_key.signing.id]
  comment = "Trusted signers for ${var.name}"
}

resource "aws_cloudfront_origin_access_control" "this" {
  name                              = var.name
  description                       = "OAC for ${var.name}"
  origin_access_control_origin_type = "s3"
  signing_behavior                  = "always"
  signing_protocol                  = "sigv4"
}

# The response-* query strings must be whitelisted, otherwise CloudFront strips
# the overrides Nexus adds and artifacts download named after their blob UUID.
resource "aws_cloudfront_cache_policy" "this" {
  name        = var.name
  comment     = "Cache policy for ${var.name}"
  min_ttl     = 0
  default_ttl = var.default_ttl
  max_ttl     = var.max_ttl

  parameters_in_cache_key_and_forwarded_to_origin {
    enable_accept_encoding_gzip   = false
    enable_accept_encoding_brotli = false

    query_strings_config {
      query_string_behavior = "whitelist"

      query_strings {
        items = [
          "response-content-disposition",
          "response-content-type",
        ]
      }
    }

    headers_config {
      header_behavior = "none"
    }

    cookies_config {
      cookie_behavior = "none"
    }
  }
}

resource "aws_cloudfront_distribution" "this" {
  enabled         = true
  is_ipv6_enabled = true
  comment         = "Nexus Repository blob store CDN (${var.bucket_name})"
  price_class     = var.price_class

  # Edge propagation takes 5-15 minutes but does not block serving.
  wait_for_deployment = false

  origin {
    origin_id = "s3-${var.bucket_name}"
    # Regional endpoint: the global one 307-redirects outside us-east-1 and CloudFront caches that.
    domain_name              = var.bucket_regional_domain_name
    origin_access_control_id = aws_cloudfront_origin_access_control.this.id
  }

  default_cache_behavior {
    target_origin_id = "s3-${var.bucket_name}"
    # https-only: a redirect would send the signed URL over cleartext once.
    viewer_protocol_policy = "https-only"
    allowed_methods        = ["GET", "HEAD"]
    cached_methods         = ["GET", "HEAD"]
    # Repository artifacts are already compressed.
    compress           = false
    cache_policy_id    = aws_cloudfront_cache_policy.this.id
    trusted_key_groups = [aws_cloudfront_key_group.signing.id]
  }

  restrictions {
    geo_restriction {
      restriction_type = "none"
    }
  }

  # Default *.cloudfront.net certificate (AWS pins TLSv1 with it). For a custom
  # hostname add an ACM certificate in us-east-1 plus aliases here.
  viewer_certificate {
    cloudfront_default_certificate = true
  }
}

resource "aws_cloudfront_monitoring_subscription" "this" {
  count = var.enable_additional_metrics ? 1 : 0

  distribution_id = aws_cloudfront_distribution.this.id

  monitoring_subscription {
    realtime_metrics_subscription_config {
      realtime_metrics_subscription_status = "Enabled"
    }
  }
}
