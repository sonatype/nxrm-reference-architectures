#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

# =============================================================================
# RA-1 (XSmall) - Self-Managed Configuration
# =============================================================================
# Use case: Development environments and small teams
# Compute:  1x Standard_D4ds_v5 (4 vCPU, 16 GiB RAM)
# Database: H2 embedded (no PostgreSQL server)
# Storage:  File blob store on the node data disk
# HA:       No (single node, TLS terminated by nginx behind a public load balancer)
#
# Prerequisites:
#   1. Place the Nexus Repository installer tarball in files_to_upload_to_nodes/
#   2. (Optional) Place a .lic file there for Pro features
#   3. A TLS certificate stored in your Key Vault
#
# Deploy with:
#   terraform apply -var-file=tfvars/ra-1-selfmanaged.tfvars
# =============================================================================

# -- Required: set these for your environment ----------------------------------
# azure_subscription_id    = "<subscription GUID>"
# dns_name                 = "nexus.example.com"
# certificate_key_vault_id = "/subscriptions/<subscription GUID>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault>"
# certificate_secret_id    = "https://<vault>.vault.azure.net/secrets/<certificate name>"

# -- Optional: Azure DNS record for dns_name -----------------------------------
# dns_zone_name           = "example.com"
# dns_zone_resource_group = "<dns zone resource group>"

location         = "eastus"
environment_name = "ra1"

# -- Compute ---------------------------------------------------------------------
cluster_size           = 1
vm_size                = "Standard_D4ds_v5"
nexus_data_volume_size = 128

# -- JVM -------------------------------------------------------------------------
java_min_heap          = "8g"
java_max_heap          = "8g"
java_max_direct_memory = "4g"

# -- Storage ---------------------------------------------------------------------
blobstore_type = "file"

# -- Database --------------------------------------------------------------------
database_type        = "h2"
nxrm_connection_pool = 100

# -- Tags (applied to all resources) ---------------------------------------------
# common_tags = {
#   team = "platform"
# }
