#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

# =============================================================================
# RA-5 (XLarge) - Self-Managed Configuration
# =============================================================================
# Use case: Production, extra large highly available cluster
# Compute:  4x Standard_D48ds_v5 (48 vCPU, 192 GiB RAM)
# Database: Azure Database for PostgreSQL Flexible Server MO_Standard_E32ds_v5
# Storage:  Azure Blob Storage
# HA:       Yes (4-node cluster behind Application Gateway, Pro license required)
#
# Prerequisites:
#   1. Place the Nexus Repository installer tarball in files_to_upload_to_nodes/
#   2. Place a .lic file there (required for clusters)
#   3. A TLS certificate stored in your Key Vault
#
# Deploy with:
#   terraform apply -var-file=tfvars/ra-5-selfmanaged.tfvars
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
environment_name = "ra5"

# -- Compute ---------------------------------------------------------------------
cluster_size           = 4
vm_size                = "Standard_D48ds_v5"
nexus_data_volume_size = 512

# -- JVM -------------------------------------------------------------------------
java_min_heap          = "96g"
java_max_heap          = "96g"
java_max_direct_memory = "48g"

# -- Storage ---------------------------------------------------------------------
blobstore_type = "azure"

# -- Database --------------------------------------------------------------------
database_type = "postgres"
# Validated default for the largest size; 350 is also proven for most workloads. For large spikes go to 400 or more per node,
# keeping nodes x pool below postgres_max_connections.
nxrm_connection_pool = 400
# A larger SKU (for example MO_Standard_E64ds_v5) adds capacity under sudden load spikes and cost; size to your expected peak and budget.
postgres_sku_name        = "MO_Standard_E32ds_v5"
postgres_max_connections = 5000
postgres_storage_mb      = 524288
# Implementing multi-AZ is optional, depending on the customer setup, and is outside the tested configurations.
postgres_zone_redundant_ha = false

# -- Tags (applied to all resources) ---------------------------------------------
# common_tags = {
#   team = "platform"
# }
