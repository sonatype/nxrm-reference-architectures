#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

variable "cluster_size" {
  description = "Number of Nexus nodes; one custom_data element is rendered per node"
  type        = number

  validation {
    condition     = var.cluster_size >= 1
    error_message = "cluster_size must be at least 1."
  }
}

variable "artifacts_account" {
  description = "Storage account holding the installer, license and secrets"
  type        = string
}

variable "artifacts_container" {
  description = "Container holding the installer, license and secrets"
  type        = string
}

variable "tarball_blob" {
  description = "Blob name of the Nexus installer tarball"
  type        = string
}

variable "license_blob" {
  description = "Blob name of the license file, empty when none"
  type        = string
  default     = ""
  nullable    = false
}

variable "secrets_blob" {
  description = "Blob name of the secrets JSON document (keys nexus_admin_password, db_password)"
  type        = string
}

variable "identity_client_id" {
  description = "Client ID of the user-assigned managed identity on the VMs"
  type        = string
}

variable "java_min_heap" {
  description = "JVM -Xms value, for example 16g"
  type        = string
}

variable "java_max_heap" {
  description = "JVM -Xmx value, for example 16g"
  type        = string
}

variable "java_max_direct_memory" {
  description = "JVM -XX:MaxDirectMemorySize value, for example 8g"
  type        = string
}

variable "clustered" {
  description = "Enable Nexus high availability (clustered datastore)"
  type        = bool
}

variable "database_type" {
  description = "h2 or postgres"
  type        = string

  validation {
    condition     = contains(["h2", "postgres"], var.database_type)
    error_message = "database_type must be \"h2\" or \"postgres\"."
  }
}

variable "db_host" {
  description = "PostgreSQL host name, empty for H2"
  type        = string
  default     = ""
  nullable    = false
}

variable "db_port" {
  description = "PostgreSQL port"
  type        = number
  default     = 5432
  nullable    = false
}

variable "db_name" {
  description = "PostgreSQL database name"
  type        = string
  default     = ""
  nullable    = false
}

variable "db_user" {
  description = "PostgreSQL user name"
  type        = string
  default     = ""
  nullable    = false
}

variable "nxrm_connection_pool" {
  description = "Maximum JDBC connection pool size per node"
  type        = number
  default     = 100
  nullable    = false
}

variable "blobstore_type" {
  description = "azure (created on node 0 through the REST API) or file"
  type        = string

  validation {
    condition     = contains(["azure", "file"], var.blobstore_type)
    error_message = "blobstore_type must be \"azure\" or \"file\"."
  }
}

variable "blob_account" {
  description = "Storage account of the Azure blob store, empty when blobstore_type is file"
  type        = string
  default     = ""
  nullable    = false
}

variable "blob_container" {
  description = "Container of the Azure blob store"
  type        = string
  default     = ""
  nullable    = false
}

variable "tls_mode" {
  description = "nginx (TLS on the VM, single node) or gateway (TLS on Application Gateway)"
  type        = string

  validation {
    condition     = contains(["nginx", "gateway"], var.tls_mode)
    error_message = "tls_mode must be \"nginx\" or \"gateway\"."
  }
}

variable "dns_name" {
  description = "Public DNS name clients use to reach Nexus"
  type        = string
}

variable "certificate_secret_id" {
  description = "Versionless Key Vault secret URI of the TLS certificate (PFX)"
  type        = string
}

variable "base_url" {
  description = "Nexus base URL, for example https://nexus.example.com"
  type        = string
}

variable "gateway_subnet_cidr" {
  description = "CIDR of the Application Gateway subnet, allowed on 8081 in gateway mode"
  type        = string
  default     = ""
  nullable    = false

  validation {
    condition     = var.gateway_subnet_cidr == "" || can(cidrhost(var.gateway_subnet_cidr, 0))
    error_message = "gateway_subnet_cidr must be a CIDR block such as 10.0.4.0/24 (or empty)."
  }
}

variable "nodes_subnet_cidr" {
  description = "CIDR of the nodes subnet, allowed on 8081 in gateway mode (cluster traffic)"
  type        = string
  default     = ""
  nullable    = false

  validation {
    condition     = var.nodes_subnet_cidr == "" || can(cidrhost(var.nodes_subnet_cidr, 0))
    error_message = "nodes_subnet_cidr must be a CIDR block such as 10.0.1.0/24 (or empty)."
  }
}
