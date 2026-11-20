#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

# =============================================================================
# RA-4 (Large) - Self-Managed Configuration
# =============================================================================
# Use case: Production, large highly available cluster
# Compute:  3x Standard_D32ds_v5 (32 vCPU, 128 GiB RAM)
# Database: Azure Database for PostgreSQL Flexible Server MO_Standard_E16ds_v5
# Storage:  Azure Blob Storage
# HA:       Yes (3-node cluster behind Application Gateway, Pro license required)
#
# Prerequisites:
#   1. Place the Nexus Repository installer tarball in files_to_upload_to_nodes/
#   2. Place a .lic file there (required for clusters)
#   3. A TLS certificate stored in your Key Vault
#
# Deploy with:
#   terraform apply -var-file=tfvars/ra-4-selfmanaged.tfvars
# =============================================================================

# -- Required: set these for your environment ----------------------------------
# azure_subscription_id    = "<subscription GUID>"
# dns_name                 = "nexus.example.com"
# certificate_key_vault_id = "/subscriptions/<subscription GUID>/resourceGroups/<rg>/providers/Microsoft.KeyVault/vaults/<vault>"
# certificate_secret_id    = "https://<vault>.vault.azure.net/secrets/<certificate name>"

# -- Optional: Azure DNS record for dns_name -----------------------------------
# dns_zone_name           = "example.com"
# dns_zone_resource_group = "<dns zone resource group>"

# -- Required unless Terraform runs inside the nodes subnet ---------------------
# Public IP of the machine that runs Terraform; it uploads the installer to the storage account.
# storage_allowed_ip_cidrs = ["<your public IP>"]

# -- Recommended: restrict who can reach the gateway -----------------------------
# The default 0.0.0.0/0 allows every client and also opens the blob store firewall.
# ingress_cidr_blocks = ["203.0.113.0/24"]

location         = "eastus"
environment_name = "ra4"

# -- Compute ---------------------------------------------------------------------
cluster_size           = 3
vm_size                = "Standard_D32ds_v5"
nexus_data_volume_size = 512

# -- JVM -------------------------------------------------------------------------
java_min_heap          = "64g"
java_max_heap          = "64g"
java_max_direct_memory = "24g"

# -- Storage ---------------------------------------------------------------------
blobstore_type = "azure"

# -- Database --------------------------------------------------------------------
database_type            = "postgres"
nxrm_connection_pool     = 200
postgres_sku_name        = "MO_Standard_E16ds_v5"
postgres_max_connections = 5000
# Implementing multi-AZ is optional, depending on the customer setup, and is outside the tested configurations.
postgres_zone_redundant_ha = false

# -- Tags (applied to all resources) ---------------------------------------------
# common_tags = {
#   team = "platform"
# }
