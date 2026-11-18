#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

# ---------- General ----------

variable "azure_subscription_id" {
  description = "Azure subscription ID that receives the deployment"
  type        = string

  validation {
    condition     = can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.azure_subscription_id))
    error_message = "azure_subscription_id must be a GUID."
  }
}

variable "location" {
  description = "Azure region"
  type        = string
  default     = "eastus"
}

variable "environment_name" {
  description = "Short name used as part of every resource name"
  type        = string
  default     = "nxrm"

  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.environment_name)) && length(var.environment_name) <= 10
    error_message = "environment_name must use lowercase letters, digits and hyphens, and be at most 10 characters."
  }
}

variable "common_tags" {
  description = "Tags applied to every resource"
  type        = map(string)
  default     = {}
}

# ---------- Nodes ----------

variable "cluster_size" {
  description = "Number of Nexus Repository nodes (1 is a single node, more than 1 is a cluster behind the gateway)"
  type        = number
  default     = 1

  validation {
    condition     = var.cluster_size >= 1 && var.cluster_size <= 10 && floor(var.cluster_size) == var.cluster_size
    error_message = "cluster_size must be an integer between 1 and 10."
  }
}

variable "vm_size" {
  description = "Azure VM size of the Nexus Repository nodes"
  type        = string
  default     = "Standard_D8ds_v5"
}

variable "image_publisher" {
  description = "Publisher of the VM image"
  type        = string
  default     = "Oracle"

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+$", var.image_publisher))
    error_message = "image_publisher may use only letters, digits, dot, underscore and hyphen."
  }
}

variable "image_offer" {
  description = "Offer of the VM image"
  type        = string
  default     = "Oracle-Linux"

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+$", var.image_offer))
    error_message = "image_offer may use only letters, digits, dot, underscore and hyphen."
  }
}

variable "image_sku" {
  description = "SKU of the VM image"
  type        = string
  default     = "ol102-lvm-gen2"

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+$", var.image_sku))
    error_message = "image_sku may use only letters, digits, dot, underscore and hyphen."
  }
}

variable "image_version" {
  description = "Version of the VM image"
  type        = string
  default     = "latest"

  validation {
    condition     = can(regex("^[A-Za-z0-9._-]+$", var.image_version))
    error_message = "image_version may use only letters, digits, dot, underscore and hyphen."
  }
}

variable "os_disk_size_gb" {
  description = "OS disk size in GB"
  type        = number
  default     = 64
}

variable "nexus_data_volume_size" {
  description = "Size in GB of the Nexus data disk"
  type        = number
  default     = 128
}

variable "nexus_data_volume_type" {
  description = "Managed disk type of the Nexus data disk"
  type        = string
  default     = "PremiumV2_LRS"

  validation {
    condition     = contains(["Premium_LRS", "PremiumV2_LRS"], var.nexus_data_volume_type)
    error_message = "nexus_data_volume_type must be Premium_LRS or PremiumV2_LRS."
  }
}

variable "zone" {
  description = "Availability zone of the nodes and their disks"
  type        = string
  default     = "1"

  validation {
    condition     = contains(["1", "2", "3"], var.zone)
    error_message = "zone must be 1, 2 or 3."
  }
}

variable "java_min_heap" {
  description = "JVM minimum heap (-Xms value)"
  type        = string
  default     = "16g"

  validation {
    condition     = can(regex("^[0-9]+[kKmMgG]$", var.java_min_heap))
    error_message = "java_min_heap must be a number followed by k, m or g (for example 16g)."
  }
}

variable "java_max_heap" {
  description = "JVM maximum heap (-Xmx value)"
  type        = string
  default     = "16g"

  validation {
    condition     = can(regex("^[0-9]+[kKmMgG]$", var.java_max_heap))
    error_message = "java_max_heap must be a number followed by k, m or g (for example 16g)."
  }
}

variable "java_max_direct_memory" {
  description = "JVM maximum direct memory (-XX:MaxDirectMemorySize value)"
  type        = string
  default     = "8g"

  validation {
    condition     = can(regex("^[0-9]+[kKmMgG]$", var.java_max_direct_memory))
    error_message = "java_max_direct_memory must be a number followed by k, m or g (for example 16g)."
  }
}

# ---------- Database ----------

variable "database_type" {
  description = "Database backend: h2 (single node only) or postgres (required for clusters)"
  type        = string
  default     = "postgres"

  validation {
    condition     = contains(["h2", "postgres"], var.database_type)
    error_message = "database_type must be h2 or postgres."
  }

  validation {
    condition     = var.cluster_size == 1 || var.database_type == "postgres"
    error_message = "A cluster (cluster_size > 1) requires database_type = postgres."
  }
}

variable "postgres_sku_name" {
  description = "PostgreSQL Flexible Server SKU"
  type        = string
  default     = "GP_Standard_D4ds_v5"
}

variable "postgres_storage_mb" {
  description = "PostgreSQL storage in MB"
  type        = number
  default     = 131072
}

variable "postgres_private_dns_zone_id" {
  # The identity running Terraform needs Private DNS Zone Contributor on the zone; the VNet must already be linked to it.
  description = "Existing central private DNS zone for PostgreSQL (null creates a zone and VNet link)"
  type        = string
  default     = null

  validation {
    condition     = var.postgres_private_dns_zone_id == null || can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/privateDnsZones/[^/]+$", var.postgres_private_dns_zone_id))
    error_message = "postgres_private_dns_zone_id must be an Azure private DNS zone resource ID (/subscriptions/<id>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/<zone>)."
  }
}

variable "postgres_version" {
  description = "PostgreSQL major version"
  type        = string
  default     = "16"
}

variable "postgres_max_connections" {
  description = "PostgreSQL max_connections (null keeps the server default)"
  type        = number
  default     = null
}

variable "nxrm_connection_pool" {
  description = "Maximum database connection pool size per Nexus node"
  type        = number
  default     = 100
}

variable "postgres_backup_retention_days" {
  description = "PostgreSQL backup retention in days"
  type        = number
  default     = 7
}

variable "postgres_zone" {
  description = "Availability zone of the PostgreSQL server"
  type        = string
  default     = "1"

  validation {
    condition     = contains(["1", "2", "3"], var.postgres_zone)
    error_message = "postgres_zone must be 1, 2 or 3."
  }
}

variable "postgres_zone_redundant_ha" {
  description = "Enable zone-redundant PostgreSQL high availability (optional, outside the tested configurations)"
  type        = bool
  default     = false
}

variable "db_name" {
  description = "Database name"
  type        = string
  default     = "nxrm_config"

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_]{0,62}$", var.db_name))
    error_message = "db_name must use lowercase letters, digits and underscores, start with a letter or underscore, and be at most 63 characters."
  }
}

variable "db_user" {
  description = "Database user"
  type        = string
  default     = "nexus"

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_]{0,62}$", var.db_user)) && !startswith(var.db_user, "pg_") && !contains(["azure_superuser", "azure_pg_admin", "admin", "administrator", "root", "guest", "public"], var.db_user)
    error_message = "db_user must use lowercase letters, digits and underscores, must not start with pg_, and must not be a name reserved by Azure (admin, root, azure_superuser, ...)."
  }
}

variable "db_password" {
  description = "Database password (null generates one)"
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.db_password == null ? true : length(var.db_password) >= 16
    error_message = "db_password must be at least 16 characters."
  }
}

variable "nexus_admin_password" {
  description = "Nexus admin password (null generates one)"
  type        = string
  default     = null
  sensitive   = true

  validation {
    condition     = var.nexus_admin_password == null ? true : length(var.nexus_admin_password) >= 16
    error_message = "nexus_admin_password must be at least 16 characters."
  }
}

# ---------- Storage ----------

variable "blobstore_type" {
  description = "Blob store backend: azure (Blob Storage, required for clusters) or file"
  type        = string
  default     = "azure"

  validation {
    condition     = contains(["azure", "file"], var.blobstore_type)
    error_message = "blobstore_type must be azure or file."
  }

  validation {
    condition     = var.cluster_size == 1 || var.blobstore_type == "azure"
    error_message = "A cluster (cluster_size > 1) requires blobstore_type = azure."
  }
}

variable "storage_account_tier" {
  description = "Storage account tier"
  type        = string
  default     = "Standard"
}

variable "storage_account_replication_type" {
  description = "Storage account replication type"
  type        = string
  default     = "LRS"
}

variable "use_private_endpoints" {
  # Applies to the Nexus blob account only; the installer/secrets account keeps the deployer IP allowlist.
  description = "Reach the Nexus blob account through a private endpoint in the nodes subnet (clients need a route and DNS to it)"
  type        = bool
  default     = false

  validation {
    condition     = !var.use_private_endpoints || var.blobstore_type == "azure"
    error_message = "use_private_endpoints needs blobstore_type = azure (there is no blob account otherwise)."
  }
}

variable "blob_private_dns_zone_id" {
  description = "Existing central privatelink.blob.core.windows.net zone (null creates a zone and VNet link)"
  type        = string
  default     = null

  validation {
    condition     = var.blob_private_dns_zone_id == null || can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/privateDnsZones/[^/]+$", var.blob_private_dns_zone_id))
    error_message = "blob_private_dns_zone_id must be an Azure private DNS zone resource ID."
  }

  validation {
    condition     = var.blob_private_dns_zone_id == null || var.use_private_endpoints
    error_message = "blob_private_dns_zone_id is used only with use_private_endpoints = true; unset it or enable use_private_endpoints."
  }
}

variable "installer_dir" {
  description = "Local directory holding the Nexus installer tarball and license file"
  type        = string
  default     = "files_to_upload_to_nodes"
}

# ---------- Network ----------

variable "vnet_cidr" {
  description = "Virtual network CIDR (ignored when create_network is false)"
  type        = string
  default     = "10.100.0.0/16"
}

variable "nodes_subnet_cidr" {
  description = "Subnet CIDR of the Nexus nodes"
  type        = string
  default     = "10.100.1.0/24"
}

variable "db_subnet_cidr" {
  description = "Subnet CIDR of the PostgreSQL server"
  type        = string
  default     = "10.100.3.0/24"
}

variable "gateway_subnet_cidr" {
  description = "Subnet CIDR of the Application Gateway"
  type        = string
  default     = "10.100.4.0/24"
}

variable "create_network" {
  description = "Create the VNet, subnets, NAT gateway and NSGs (true) or deploy into existing subnets (false; set the *_subnet_id variables)"
  type        = bool
  default     = true
}

variable "nodes_subnet_id" {
  # Needs the Microsoft.Storage service endpoint (and Microsoft.KeyVault on single nodes) and outbound internet.
  description = "Existing subnet of the Nexus nodes (create_network = false only)"
  type        = string
  default     = null

  validation {
    condition     = var.create_network ? var.nodes_subnet_id == null : var.nodes_subnet_id != null
    error_message = "Set nodes_subnet_id when create_network is false, and leave it unset when create_network is true."
  }

  validation {
    condition     = var.nodes_subnet_id == null || can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.nodes_subnet_id))
    error_message = "nodes_subnet_id must be an Azure subnet resource ID (/subscriptions/<id>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet>/subnets/<name>)."
  }
}

variable "db_subnet_id" {
  description = "Existing empty subnet delegated to Microsoft.DBforPostgreSQL/flexibleServers (create_network = false with database_type = postgres)"
  type        = string
  default     = null

  validation {
    condition     = var.create_network ? var.db_subnet_id == null : (var.database_type != "postgres" || var.db_subnet_id != null)
    error_message = "Set db_subnet_id when create_network is false and database_type is postgres, and leave it unset when create_network is true."
  }

  validation {
    condition     = var.db_subnet_id == null || can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.db_subnet_id))
    error_message = "db_subnet_id must be an Azure subnet resource ID."
  }

  validation {
    condition     = var.db_subnet_id == null || var.nodes_subnet_id == null || lower(try(regex("(?i)^(.*)/subnets/[^/]+$", var.db_subnet_id)[0], "")) == lower(try(regex("(?i)^(.*)/subnets/[^/]+$", var.nodes_subnet_id)[0], ""))
    error_message = "db_subnet_id must be in the same virtual network as nodes_subnet_id."
  }
}

variable "gateway_subnet_id" {
  description = "Existing dedicated Application Gateway subnet (create_network = false with cluster_size > 1)"
  type        = string
  default     = null

  validation {
    condition     = var.create_network ? var.gateway_subnet_id == null : (var.cluster_size == 1 || var.gateway_subnet_id != null)
    error_message = "Set gateway_subnet_id when create_network is false and cluster_size > 1, and leave it unset when create_network is true."
  }

  validation {
    condition     = var.gateway_subnet_id == null || can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.gateway_subnet_id))
    error_message = "gateway_subnet_id must be an Azure subnet resource ID."
  }

  validation {
    condition     = var.gateway_subnet_id == null || var.nodes_subnet_id == null || lower(try(regex("(?i)^(.*)/subnets/[^/]+$", var.gateway_subnet_id)[0], "")) == lower(try(regex("(?i)^(.*)/subnets/[^/]+$", var.nodes_subnet_id)[0], ""))
    error_message = "gateway_subnet_id must be in the same virtual network as nodes_subnet_id."
  }
}

variable "bastion_subnet_id" {
  description = "Existing AzureBastionSubnet (create_network = false with enable_bastion)"
  type        = string
  default     = null

  validation {
    condition     = var.create_network ? var.bastion_subnet_id == null : (!var.enable_bastion || var.bastion_subnet_id != null)
    error_message = "Set bastion_subnet_id when create_network is false and enable_bastion is true, and leave it unset when create_network is true."
  }

  validation {
    condition     = var.bastion_subnet_id == null || can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+/subnets/[^/]+$", var.bastion_subnet_id))
    error_message = "bastion_subnet_id must be an Azure subnet resource ID."
  }

  validation {
    condition     = var.bastion_subnet_id == null || var.nodes_subnet_id == null || lower(try(regex("(?i)^(.*)/subnets/[^/]+$", var.bastion_subnet_id)[0], "")) == lower(try(regex("(?i)^(.*)/subnets/[^/]+$", var.nodes_subnet_id)[0], ""))
    error_message = "bastion_subnet_id must be in the same virtual network as nodes_subnet_id."
  }
}

variable "node_private_ips" {
  # Default: .10 upward in the created subnet, Azure-assigned in an existing one (create_network = false).
  description = "Static private IPs of the nodes, one per node (null picks the default)"
  type        = list(string)
  default     = null

  validation {
    condition     = var.node_private_ips == null ? true : length(var.node_private_ips) == var.cluster_size
    error_message = "node_private_ips must list exactly cluster_size addresses (one per node)."
  }

  validation {
    condition     = var.node_private_ips == null ? true : alltrue([for ip in var.node_private_ips : can(regex("^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$", ip))])
    error_message = "node_private_ips must contain valid IPv4 addresses inside the nodes subnet."
  }
}

variable "ingress_cidr_blocks" {
  description = "CIDR blocks allowed to reach the gateway on 80/443"
  type        = list(string)
  default     = ["0.0.0.0/0"]

  validation {
    condition     = length(var.ingress_cidr_blocks) > 0
    error_message = "ingress_cidr_blocks must list at least one IPv4 CIDR block (use [\"0.0.0.0/0\"] to allow every client)."
  }

  validation {
    condition     = alltrue([for c in var.ingress_cidr_blocks : can(regex("^[0-9]{1,3}(\\.[0-9]{1,3}){3}/[0-9]{1,2}$", c)) && can(cidrhost(c, 0))])
    error_message = "Every ingress_cidr_blocks entry must be a valid IPv4 CIDR such as 203.0.113.0/24; write a single address as 203.0.113.7/32."
  }
}

variable "storage_allowed_ip_cidrs" {
  description = "Extra public IPs or CIDRs allowed on the storage account firewall"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for c in var.storage_allowed_ip_cidrs : !can(regex("^(10\\.[0-9.]+(/([89]|[12][0-9]|3[0-2]))?|172\\.(1[6-9]|2[0-9]|3[01])\\.[0-9.]+(/(1[2-9]|2[0-9]|3[0-2]))?|192\\.168\\.[0-9.]+(/(1[6-9]|2[0-9]|3[0-2]))?)$", c))])
    error_message = "storage_allowed_ip_cidrs must hold public addresses: the storage firewall rejects private ranges (10/8, 172.16/12, 192.168/16). Private clients reach storage through the nodes subnet or a private endpoint."
  }
}

variable "blob_client_subnet_ids" {
  # Azure ignores IP rules for clients in the storage account's own region; subnets with the Microsoft.Storage endpoint work.
  description = "Subnets of Azure-hosted clients (same region as the storage account) allowed to download from the blob account"
  type        = list(string)
  default     = []

  validation {
    condition     = alltrue([for s in var.blob_client_subnet_ids : can(regex("(?i)^/subscriptions/[^/]+/resourceGroups/[^/]+/providers/Microsoft\\.Network/virtualNetworks/[^/]+/subnets/[^/]+$", s))])
    error_message = "Every blob_client_subnet_ids entry must be an Azure subnet resource ID (/subscriptions/<id>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet>/subnets/<name>)."
  }
}

variable "detect_deployer_ip" {
  description = "Detect the deployer public IP and add it to the storage account firewall"
  type        = bool
  default     = true
}

# ---------- HTTPS ----------

variable "dns_name" {
  description = "Fully qualified DNS name served by the gateway"
  type        = string

  validation {
    condition     = can(regex("^([a-z0-9]([a-z0-9-]*[a-z0-9])?\\.)+[a-z]{2,}$", var.dns_name))
    error_message = "dns_name must be a lowercase fully qualified name without a trailing dot."
  }
}

variable "certificate_key_vault_id" {
  description = "Resource ID of the Key Vault that holds the TLS certificate"
  type        = string
}

variable "certificate_secret_id" {
  description = "Versionless Key Vault secret URI of the TLS certificate"
  type        = string

  validation {
    condition     = can(regex("^https://[a-z0-9-]+\\.vault\\.azure\\.net/secrets/[A-Za-z0-9-]+/?$", var.certificate_secret_id))
    error_message = "certificate_secret_id must be a versionless Key Vault secret URI."
  }
}

variable "frontend_visibility" {
  # private: internal load balancer (single node) or a private gateway listener (cluster); no public A record.
  description = "Client entry point: public (public IP) or private (address inside the VNet)"
  type        = string
  default     = "public"

  validation {
    condition     = contains(["public", "private"], var.frontend_visibility)
    error_message = "frontend_visibility must be public or private."
  }
}

variable "private_frontend_ip" {
  # Single node: optional address in the nodes subnet. Cluster: required address in the gateway subnet.
  description = "Static IPv4 of the private frontend (frontend_visibility = private only)"
  type        = string
  default     = null

  validation {
    condition     = var.private_frontend_ip == null ? true : can(regex("^((25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])\\.){3}(25[0-5]|2[0-4][0-9]|1[0-9]{2}|[1-9]?[0-9])$", var.private_frontend_ip))
    error_message = "private_frontend_ip must be a valid IPv4 address."
  }

  validation {
    condition     = var.private_frontend_ip == null || var.frontend_visibility == "private"
    error_message = "private_frontend_ip is used only with frontend_visibility = private; unset it or set frontend_visibility."
  }

  validation {
    condition     = var.frontend_visibility != "private" || var.cluster_size == 1 || var.private_frontend_ip != null
    error_message = "A cluster with frontend_visibility = private needs private_frontend_ip (a free address in the gateway subnet)."
  }
}

variable "dns_zone_name" {
  description = "Azure DNS zone that receives the A record (empty skips the record)"
  type        = string
  default     = ""

  validation {
    condition     = var.dns_zone_name == "" || var.frontend_visibility == "public"
    error_message = "dns_zone_name creates a public A record and cannot be combined with frontend_visibility = private; leave dns_zone_name empty and point a private DNS record at private_frontend_ip_address."
  }
}

variable "dns_zone_resource_group" {
  description = "Resource group of the Azure DNS zone"
  type        = string
  default     = ""
}

variable "gateway_min_capacity" {
  description = "Application Gateway autoscale minimum instance count; each instance reserves 10 capacity units, billed even when idle (2 to 100)"
  type        = number
  default     = 2

  validation {
    condition     = var.gateway_min_capacity >= 2 && var.gateway_min_capacity <= 100 && floor(var.gateway_min_capacity) == var.gateway_min_capacity
    error_message = "gateway_min_capacity must be a whole number from 2 to 100: Azure accepts an Application Gateway autoscale minimum of 0 to 100 instances (the template needs 2 or more)."
  }
}

variable "gateway_request_timeout_seconds" {
  description = "Application Gateway backend request timeout in seconds"
  type        = number
  default     = 900
}

# ---------- Access ----------

variable "enable_bastion" {
  # Enable when support needs shell access to private nodes (thread dumps, log tails); az vm run-command is the free alternative.
  # Bills hourly from deployment (East US): Basic $0.19, Standard $0.29, Premium $0.45.
  # Gains: no VM public IPs or inbound SSH, TLS on 443, Entra ID sign-in (az network bastion ssh --auth-type AAD), audit trail.
  description = "Deploy Azure Bastion for SSH access to the nodes"
  type        = bool
  default     = false
}

variable "bastion_sku" {
  description = "Azure Bastion SKU"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.bastion_sku)
    error_message = "bastion_sku must be Basic, Standard or Premium."
  }
}

variable "bastion_subnet_cidr" {
  description = "Subnet CIDR of Azure Bastion (at least /26)"
  type        = string
  default     = "10.100.5.0/26"
}

variable "admin_username" {
  description = "Admin user of the VMs"
  type        = string
  default     = "azureuser"

  validation {
    condition     = can(regex("^[a-z_][a-z0-9_-]{0,31}$", var.admin_username))
    error_message = "admin_username must be a lowercase Linux user name (letters, digits, underscore, hyphen; at most 32 characters)."
  }
}

variable "admin_ssh_public_key" {
  description = "SSH public key of the admin user (empty uses a generated key)"
  type        = string
  default     = ""
}

variable "bastion_user_principal_ids" {
  # Static Entra ID object IDs (users or groups), known before apply; they get VM Administrator Login.
  description = "Entra ID object IDs allowed to SSH to the nodes through Bastion"
  type        = list(string)
  default     = []
}
