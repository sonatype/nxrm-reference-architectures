#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

locals {
  template_dir = "${path.module}/../../scripts/templates"

  # Shared by every script; node_index is added per node.
  template_vars = {
    artifacts_account      = var.artifacts_account
    artifacts_container    = var.artifacts_container
    tarball_blob           = var.tarball_blob
    license_blob           = var.license_blob
    key_vault_name         = var.key_vault_name
    admin_secret_name      = var.admin_secret_name
    db_secret_name         = var.db_secret_name
    identity_client_id     = var.identity_client_id
    java_min_heap          = var.java_min_heap
    java_max_heap          = var.java_max_heap
    java_max_direct_memory = var.java_max_direct_memory
    clustered              = var.clustered
    database_type          = var.database_type
    db_host                = var.db_host
    db_port                = var.db_port
    db_name                = var.db_name
    db_user                = var.db_user
    nxrm_connection_pool   = var.nxrm_connection_pool
    blobstore_type         = var.blobstore_type
    blob_account           = var.blob_account
    blob_container         = var.blob_container
    tls_mode               = var.tls_mode
    dns_name               = var.dns_name
    certificate_secret_id  = var.certificate_secret_id
    app_port_sources       = compact(distinct([var.gateway_subnet_cidr, var.nodes_subnet_cidr]))
  }

  # Execution order; optional steps are dropped per node.
  run_order = [
    for i in range(var.cluster_size) : compact([
      "setup-storage",
      "install-nexus",
      "configure-nexus",
      var.tls_mode == "nginx" ? "nginx-tls" : "",
      "start-nexus",
      i == 0 && var.blobstore_type == "azure" ? "create-blobstore" : "",
    ])
  ]

  node_scripts = [
    for i in range(var.cluster_size) : {
      for name in local.run_order[i] :
      name => templatefile("${local.template_dir}/${name}.sh.tpl", merge(local.template_vars, { node_index = i }))
    }
  ]

  # Sourced by the other scripts: written to every node, never run on its own.
  lib_script = templatefile("${local.template_dir}/lib.sh.tpl", local.template_vars)

  # Scripts are gzipped inside the cloud-config to stay well below the 64 KB custom_data limit.
  custom_data = [
    for i in range(var.cluster_size) : base64encode(templatefile("${local.template_dir}/cloud-init.yaml.tpl", {
      scripts   = { for name, text in merge({ lib = local.lib_script }, local.node_scripts[i]) : name => base64gzip(text) }
      run_order = local.run_order[i]
    }))
  ]
}
