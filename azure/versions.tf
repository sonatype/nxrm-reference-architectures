#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

terraform {
  required_version = ">= 1.11"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.0"
    }
    # Waits for the role that lets Terraform write the Key Vault secrets.
    time = {
      source  = "hashicorp/time"
      version = "~> 0.12"
    }
    http = {
      source  = "hashicorp/http"
      version = "~> 3.0"
    }
    # Only generates an SSH key when admin_ssh_public_key is empty.
    tls = {
      source  = "hashicorp/tls"
      version = "~> 4.0"
    }
  }
}
