#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

output "distribution_arn" {
  description = "CloudFront distribution ARN"
  value       = aws_cloudfront_distribution.this.arn
}

output "distribution_domain" {
  description = "Distribution URL to configure in Nexus"
  value       = "https://${aws_cloudfront_distribution.this.domain_name}"
}

output "key_pair_id" {
  description = "Public key ID, sent as the Key-Pair-Id parameter of a signed URL"
  value       = aws_cloudfront_public_key.signing.id
}

# PKCS#8: the AWS SDK for Java parses PKCS#8 only.
output "signing_private_key" {
  description = "PKCS#8 PEM private key Nexus signs URLs with"
  value       = tls_private_key.signing.private_key_pem_pkcs8
  sensitive   = true
}
