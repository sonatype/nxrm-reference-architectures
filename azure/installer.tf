#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

locals {
  installer_files = fileset("${path.root}/${var.installer_dir}", "nexus*.tar.gz")
  license_files   = fileset("${path.root}/${var.installer_dir}", "*.lic")
  has_license     = length(local.license_files) > 0

  storage_allowed_ips = concat(
    var.detect_deployer_ip ? [trimspace(data.http.deployer_ip[0].response_body)] : [],
    var.storage_allowed_ip_cidrs,
  )
}

# Public IP of the machine running Terraform, needed to upload to the private storage account.
data "http" "deployer_ip" {
  count = var.detect_deployer_ip ? 1 : 0
  url   = "https://api.ipify.org"

  lifecycle {
    postcondition {
      condition     = self.status_code == 200
      error_message = "Could not detect the deployer public IP; list the deployer address in storage_allowed_ip_cidrs and set detect_deployer_ip = false."
    }
  }
}

# Warns only: a deployer inside the nodes subnet reaches the installer account without an IP rule.
check "deployer_ip_allowed" {
  assert {
    condition     = var.detect_deployer_ip || length(var.storage_allowed_ip_cidrs) > 0
    error_message = "No deployer IP is allowed on the installer storage account, so the installer upload fails with 403 unless Terraform runs inside the nodes subnet. Set storage_allowed_ip_cidrs to the public IP of this machine."
  }
}

resource "terraform_data" "validate_installer" {
  lifecycle {
    precondition {
      condition     = length(local.installer_files) == 1
      error_message = "Place exactly one nexus*.tar.gz file in ${var.installer_dir}/ (e.g., nexus-3.98.0-07-linux-x86_64.tar.gz)"
    }

    precondition {
      condition     = length(local.license_files) <= 1
      error_message = "Place at most one *.lic file in ${var.installer_dir}/ (optional for a single node, required for clusters)"
    }

    precondition {
      condition     = !local.is_clustered || local.has_license
      error_message = "A license file (*.lic) is required in ${var.installer_dir}/ for clustered deployments. Clustering requires NXRM Pro edition."
    }
  }
}
