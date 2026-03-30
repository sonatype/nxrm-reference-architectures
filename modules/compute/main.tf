#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

# -----------------------------------------------------------------------------
# AMI Lookup (Amazon Linux 2023)
# -----------------------------------------------------------------------------

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]

  filter {
    name   = "name"
    values = ["al2023-ami-2023.*-${var.instance_arch}"]
  }

  filter {
    name   = "owner-alias"
    values = ["amazon"]
  }
}

# -----------------------------------------------------------------------------
# Rendered configuration scripts from templates
# -----------------------------------------------------------------------------

locals {
  setup_storage_script = templatefile("${path.root}/scripts/templates/setup-storage.sh.tpl", {
    volume_size      = var.nexus_data_volume_size
    volume_type      = var.nexus_data_volume_type
    blobstore_type   = var.blobstore_type
    blob_volume_size = var.nexus_blob_volume_size
    blob_volume_type = var.nexus_blob_volume_type
  })

  configure_nexus_script = templatefile("${path.root}/scripts/templates/configure-nexus.sh.tpl", {
    ra_size              = var.ra_size
    clustered            = var.is_clustered
    db_engine            = var.database_type
    db_host              = var.rds_endpoint
    db_port              = "5432"
    db_name              = "nxrm"
    db_username          = var.db_username
    db_password          = var.db_password
    db_connection_pool   = var.db_connection_pool
    java_heap_min        = var.java_min_heap
    java_heap_max        = var.java_max_heap
    java_direct_memory   = var.java_max_direct_memory
    instance_arch        = var.instance_arch
    blobstore_type       = var.blobstore_type
    s3_bucket            = var.blobstore_bucket
    s3_region            = var.aws_region
    nexus_admin_password = var.nexus_admin_password
  })

  user_data = templatefile("${path.root}/scripts/templates/user-data.sh.tpl", {
    artifact_bucket        = var.artifact_bucket_name
    aws_region             = var.aws_region
    setup_storage_script   = local.setup_storage_script
    configure_nexus_script = local.configure_nexus_script
  })
}

# -----------------------------------------------------------------------------
# EC2 Instances
# -----------------------------------------------------------------------------

resource "aws_instance" "nxrm" {
  count                       = var.cluster_size
  ami                         = data.aws_ami.al2023.id
  instance_type               = var.instance_type
  key_name                    = var.key_pair_id
  iam_instance_profile        = var.instance_profile_name
  subnet_id                   = var.subnet_ids[count.index % length(var.subnet_ids)]
  vpc_security_group_ids      = [var.security_group_id]
  monitoring                  = true
  associate_public_ip_address = false

  metadata_options {
    http_endpoint               = "enabled"
    http_tokens                 = "required"
    http_put_response_hop_limit = 1
  }

  root_block_device {
    encrypted = true
  }

  # NXRM operation volume (sonatype-work, logs, db files)
  ebs_block_device {
    device_name = "/dev/xvdh"
    volume_size = var.nexus_data_volume_size
    volume_type = var.nexus_data_volume_type
    encrypted   = true
  }

  # NXRM blob storage volume (file blobstore only)
  dynamic "ebs_block_device" {
    for_each = var.blobstore_type == "file" ? [1] : []
    content {
      device_name = "/dev/xvdi"
      volume_size = var.nexus_blob_volume_size
      volume_type = var.nexus_blob_volume_type
      encrypted   = true
    }
  }

  user_data = local.user_data

  tags = {
    Name = "${var.name_prefix}-node-${count.index + 1}"
  }
}
