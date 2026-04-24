#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

locals {
  use_s3_blobstore = var.blobstore_type == "s3"
}

# -----------------------------------------------------------------------------
# EC2 Instance Role (self-managed deployments)
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "ec2_assume_role" {
  statement {
    actions = ["sts:AssumeRole"]
    principals {
      type        = "Service"
      identifiers = ["ec2.amazonaws.com"]
    }
  }
}

resource "aws_iam_role" "ec2" {
  name_prefix        = "${var.name_prefix}-ec2-"
  assume_role_policy = data.aws_iam_policy_document.ec2_assume_role.json

  tags = {
    Name = "${var.name_prefix}-ec2-role"
  }
}

resource "aws_iam_instance_profile" "ec2" {
  name_prefix = "${var.name_prefix}-ec2-"
  role        = aws_iam_role.ec2.name
}

# -----------------------------------------------------------------------------
# S3 Blob Store Access Policy (only when blobstore_type = s3)
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "s3_blobstore" {
  count = local.use_s3_blobstore ? 1 : 0

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
      "s3:GetBucketPolicy",
    ]
    resources = [
      var.blobstore_bucket_arn != null ? var.blobstore_bucket_arn : "",
      var.blobstore_bucket_arn != null ? "${var.blobstore_bucket_arn}/*" : "",
    ]
  }
}

resource "aws_iam_policy" "s3_blobstore" {
  count       = local.use_s3_blobstore ? 1 : 0
  name_prefix = "${var.name_prefix}-s3-blobstore-"
  description = "Allow NXRM access to S3 blob store bucket"
  policy      = data.aws_iam_policy_document.s3_blobstore[0].json
}

resource "aws_iam_role_policy_attachment" "s3_blobstore" {
  count      = local.use_s3_blobstore ? 1 : 0
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.s3_blobstore[0].arn
}

# -----------------------------------------------------------------------------
# S3 Artifact Bucket Access Policy (self-managed: download installer from S3)
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "s3_artifacts" {
  statement {
    sid = "NXRMArtifactAccess"
    actions = [
      "s3:GetObject",
      "s3:ListBucket",
    ]
    resources = [
      var.artifact_bucket_arn,
      "${var.artifact_bucket_arn}/*",
    ]
  }
}

resource "aws_iam_policy" "s3_artifacts" {
  name_prefix = "${var.name_prefix}-s3-artifacts-"
  description = "Allow NXRM instances to read deployment artifacts from S3"
  policy      = data.aws_iam_policy_document.s3_artifacts.json
}

resource "aws_iam_role_policy_attachment" "s3_artifacts" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.s3_artifacts.arn
}

# -----------------------------------------------------------------------------
# CloudWatch Access Policy
# -----------------------------------------------------------------------------

data "aws_iam_policy_document" "cloudwatch" {
  statement {
    sid = "NXRMCloudWatchAccess"
    actions = [
      "cloudwatch:PutMetricData",
      "ec2:DescribeVolumes",
      "ec2:DescribeTags",
      "logs:PutLogEvents",
      "logs:DescribeLogStreams",
      "logs:DescribeLogGroups",
      "logs:CreateLogStream",
      "logs:CreateLogGroup",
    ]
    resources = ["*"]
  }
}

resource "aws_iam_policy" "cloudwatch" {
  name_prefix = "${var.name_prefix}-cloudwatch-"
  description = "Allow NXRM instances to publish CloudWatch metrics and logs"
  policy      = data.aws_iam_policy_document.cloudwatch.json
}

resource "aws_iam_role_policy_attachment" "cloudwatch" {
  role       = aws_iam_role.ec2.name
  policy_arn = aws_iam_policy.cloudwatch.arn
}

# -----------------------------------------------------------------------------
# SSM Access Policy (for Session Manager)
# -----------------------------------------------------------------------------

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.ec2.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

