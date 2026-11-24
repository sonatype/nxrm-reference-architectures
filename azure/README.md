# Sonatype Nexus Repository Infrastructure as Code - Azure Reference Architectures

This folder provides pre-configured reference architectures for small, mid-sized, and large-scale enterprise deployments to enable you to deploy Sonatype Nexus Repository on Azure using Terraform.

## ⚠️ Cost and Responsibility Disclaimer

**IMPORTANT:** Deploying this infrastructure will incur Azure charges including compute (virtual machines, Azure Database for PostgreSQL Flexible Server), storage (managed disks, Blob Storage), networking (Application Gateway or Load Balancer, NAT Gateway, public IP addresses, data transfer), Key Vault reads, the optional Azure Bastion, and other Azure services. Azure costs vary by region, VM sizes, data transfer volumes, and usage patterns.

**You are solely responsible for:**
- Monitoring and managing all Azure costs associated with deployed resources
- Understanding Azure pricing before deployment
- Cleaning up resources when no longer needed to avoid ongoing charges
- Reviewing and optimizing your deployment for cost efficiency
- Restricting network access (`ingress_cidr_blocks`) and protecting your data (backups, versioning, delete protection) for your own requirements

**Sonatype provides this template as-is to help you deploy Nexus Repository infrastructure but bears no responsibility for any Azure costs you incur.** Use Azure Cost Management and budget alerts to track your spending.

---

## What This Provides

- **5 Reference Architecture sizes** (extra-small, small, medium, large, and extra-large) with pre-tuned configurations
- **High Availability (HA)** support with multi-node clustering in reference architectures 3–5 (i.e., medium through extra-large with a paid Pro license). These tiers survive the loss of a node, not of an availability zone: all nodes, data disks and the NAT gateway run in one zone (`zone`), and PostgreSQL zone-redundant HA is off by default
- **PostgreSQL or H2 database options** H2 only available for size extra-small; note that PostgreSQL is highly recommended for all deployments and required for HA deployments
- **Azure Blob Storage or local disk blob storage** The local disk can only be used with the extra-small and small architectures; sizes small through extra-large default to Azure Blob Storage, and Blob Storage is required for HA deployments
- **HTTPS front end** with a TLS certificate from your Azure Key Vault: Nginx behind a Standard Load Balancer for single-node sizes, Application Gateway v2 for clustered sizes
- **Automated password management** via Terraform outputs
- **Security features** including encrypted storage, no public IP addresses on the VMs, a managed identity instead of stored keys, storage account firewalls, and network security groups that only admit the traffic each subnet needs
- **One-command deployment** with minimal configuration required

It is important to choose the correct reference architecture for your organization's needs. Reference architecture documentation to help you choose the appropriate architecture size is available in Sonatype's help documentation under [Sonatype Reference Architectures](https://help.sonatype.com/en/sonatype-nexus-repository-reference-architectures.html).

---

## Prerequisites

### 1. Azure Subscription Setup

**Required Azure permissions** on the target subscription (or resource group scope):
- Create resource groups, virtual networks, virtual machines, managed disks, Storage accounts, PostgreSQL Flexible Servers, public IP addresses, NAT Gateways, load balancers, and Application Gateways
- Create role assignments (for example **Owner**, or **Contributor** plus **User Access Administrator**)
- Assign the **Key Vault Secrets User** role on the certificate secret in the Key Vault that holds your certificate

**vCPU quota.** Check the regional vCPU quota of your subscription before you deploy. The VM family is `Dds_v5`; the database uses an E-series (memory optimized) or D-series (general purpose) Flexible Server SKU.

| RA Size | VM vCPUs | Database vCPUs | Total |
|---------|----------|----------------|-------|
| **RA-1 (XSmall)** | 4 | 0 (H2) | 4 |
| **RA-2 (Small)** | 8 | 4 | 12 |
| **RA-3 (Medium)** | 24 (3 x 8) | 8 | 32 |
| **RA-4 (Large)** | 96 (3 x 32) | 16 | 112 |
| **RA-5 (XLarge)** | 192 (4 x 48) | 32 | 224 |

Request a quota increase for the `Standard DDSv5 Family` and for PostgreSQL Flexible Server vCPUs in your region if needed.

### 2. Tools Installation

```bash
# Terraform >= 1.11 (older versions may work but have not been tested)
terraform version

# Azure CLI, logged in to the target subscription
az login
az account show

# jq (optional, for parsing JSON outputs)
which jq
```

### 3. Nexus Repository Installer Files

**Download the installer:**
1. Go to [Sonatype Help Center](https://help.sonatype.com/en/download.html)
    - The VMs are x86_64. Download the **x86_64 Linux** version.
2. Download the **Unix/Linux (.tar.gz)** version
3. Download your **Pro license file** (.lic). It is required for RA-3 through RA-5 because clustering needs Pro. For RA-2 a Pro license is recommended; the template does not require one on a single node. RA-1 can use Community Edition.

The template was tested with a Nexus Repository 3.98.x build; other recent 3.x releases are expected to work. Try your own version in a non-production environment first.

**⚠️ Changing the installer or the license later replaces every VM at once.** The tarball and license file are part of the VM bootstrap input, so a new file name or content makes Terraform recreate all nodes in the same apply (an outage). The data disks and the database are kept. Plan upgrades for a maintenance window and review `terraform plan` first.

**Place files in the folder:**
```bash
# Navigate to the Azure template folder
cd nxrm-reference-architectures/azure

# Copy installer (any filename starting with 'nexus' and ending with '.tar.gz')
cp ~/Downloads/nexus-*.tar.gz files_to_upload_to_nodes/

# Copy license file (optional for RA-1 and RA-2 - required for RA-3+)
cp ~/Downloads/your-license.lic files_to_upload_to_nodes/

# Verify files are present
ls -lh files_to_upload_to_nodes/
```

**Expected files:**
```
files_to_upload_to_nodes/
├── nexus-3.98.0-07-linux-x86_64.tar.gz   (your installer)
├── your-license.lic                      (optional for RA-1 and RA-2, required for RA-3+)
└── README.md
```

### 4. TLS Certificate and DNS Name (Required)

HTTPS is mandatory. There is no HTTP-only mode. You need:

1. **A TLS certificate stored in Azure Key Vault as a certificate** (PFX/PKCS#12). The template reads the certificate's secret URI and passes it as `certificate_secret_id`. Use the versionless URI so renewals are picked up, for example `https://my-vault.vault.azure.net/secrets/nexus-cert`. A certificate imported in PEM format is rejected on single-node sizes: import it as PFX.
2. **A Key Vault that uses Azure RBAC authorization** (not access policies). Terraform grants the **Key Vault Secrets User** role on the certificate secret only, not on the whole vault: to the Application Gateway's own managed identity on clustered sizes, or to the node identity on single-node sizes. `certificate_secret_id` must be in the vault you pass as `certificate_key_vault_id`; the plan fails otherwise.
   - **Key Vault firewall:** if the vault does not allow all networks, single-node sizes (RA-1, RA-2) read the certificate from the nodes: add a virtual network rule for the nodes subnet (the template enables the `Microsoft.KeyVault` service endpoint on it). Clustered sizes read it through the Application Gateway: enable **Allow trusted Microsoft services to bypass this firewall** on the vault.
3. **A DNS name you control** (`dns_name`, for example `nexus.example.com`). The certificate must cover this name.
4. **The A record.** Either:
   - Set `dns_zone_name` and `dns_zone_resource_group` (both are required together) to an existing Azure DNS zone, and Terraform creates the A record. `dns_name` must be a host inside that zone.
   - Or leave both empty and create an A record from `dns_name` to the `front_end_public_ip` output yourself, after `terraform apply`.

---

## Quick Start

### Step 1: Choose Your Reference Architecture

| RA Size | Use Case | Compute | License | Database | Storage | HA |
|---------|----------|---------|---------|----------|---------|-----|
| **RA-1 (XSmall)** | Dev/Test | 1x Standard_D4ds_v5 | CE or Pro | H2 | Local disk | No |
| **RA-2 (Small)** | Small Prod | 1x Standard_D8ds_v5 | Pro (recommended) | PostgreSQL | Blob Storage or local disk | No |
| **RA-3 (Medium)** | Medium Prod | 3x Standard_D8ds_v5 | Pro | PostgreSQL | Blob Storage | Yes |
| **RA-4 (Large)** | Large Prod | 3x Standard_D32ds_v5 | Pro | PostgreSQL | Blob Storage | Yes |
| **RA-5 (XLarge)** | Enterprise | 4x Standard_D48ds_v5 | Pro | PostgreSQL | Blob Storage | Yes |

**For this example, we'll deploy RA-1 (XSmall).**

### Step 2: Configure Your Deployment

```bash
# Copy the RA-1 template
cp tfvars/ra-1-selfmanaged.tfvars terraform.tfvars

# Edit the configuration
nano terraform.tfvars  # or vim, code, etc.
```

The size tfvars already set `environment_name` (`ra1` to `ra5`, part of every resource name, at most 10 characters) and `location = "eastus"`. Change `location` if you deploy elsewhere; the template needs a region with availability zones.

**Minimal configuration (required):**
```hcl
# terraform.tfvars

# Fully qualified name that serves Nexus Repository
dns_name = "nexus.example.com"

# Key Vault that holds the certificate, and the versionless secret URI of the certificate
certificate_key_vault_id = "/subscriptions/<subscription-id>/resourceGroups/<vault-rg>/providers/Microsoft.KeyVault/vaults/<vault-name>"
certificate_secret_id    = "https://<vault-name>.vault.azure.net/secrets/<certificate-name>"

# Public IP of the machine that runs Terraform (it uploads the installer; not needed inside the nodes subnet)
storage_allowed_ip_cidrs = ["<your public IP>"]
```

Provide the subscription without writing it to a file:
```bash
export TF_VAR_azure_subscription_id=$(az account show --query id -o tsv)
```

**Review these settings for your environment.** The defaults get you a working deployment, not a hardened one, and setting them correctly is your responsibility:

- **`ingress_cidr_blocks` (warning).** The default `["0.0.0.0/0"]` lets the whole internet reach the gateway and also opens the blob store firewall. `terraform plan` prints a warning while it is left at the default. Set it to your client ranges (see [Networking](#networking)).
- **Blob store data protection.** The template enables soft delete (7 days) on the Nexus blob store account and nothing more. Versioning, backups and protection against deleting the account (for example an Azure resource lock) are yours to add according to your recovery needs. `terraform destroy` deletes the account and its contents.
- **Base URL, state and TLS.** See [Access Nexus Repository](#step-5-access-nexus-repository) and [State and Secrets](#state-and-secrets).

See [Customization Options](#customization-options) for advanced configuration.

### Step 3: Deploy

```bash
# Initialize Terraform (first time only)
terraform init

# Preview what will be created
terraform plan

# Deploy (typically around 25 minutes; varies)
terraform apply
```

The installer is uploaded from your machine as part of the apply, so a slow connection adds several minutes. To override a value on the command line, put `-var` after any `-var-file`; the later value wins.

**Terraform will create:**
- A resource group, virtual network with subnets, and a NAT Gateway for outbound traffic
- Virtual machine(s) running Nexus Repository, with no public IP addresses
- A Standard Load Balancer with Nginx on the node (single-node sizes) or an Application Gateway v2 (clustered sizes)
- A Storage account for Blob Storage and for the installer files, a Key Vault for the generated passwords, and managed identities (one for the nodes and, on clustered sizes, one for the Application Gateway)
- Azure Database for PostgreSQL Flexible Server (RA-2 and above)
- Network security groups and, optionally, the DNS A record and Azure Bastion

**First apply of a clustered size:** the Application Gateway may fail to read the certificate because the role assignment on your Key Vault has not propagated yet. Run `terraform apply` again. It resumes where it stopped.

### Step 4: Get Your Access Information

After deployment completes, retrieve your credentials:

```bash
# Get the Nexus Repository URL
terraform output nxrm_url

# Get the admin password
terraform output -raw nexus_admin_password

# Get the public IP for your DNS A record (if Terraform did not create it)
terraform output front_end_public_ip
```

**Example output:**
```
nxrm_url = "https://nexus.example.com"
<your-admin-password>
```

### Step 5: Access Nexus Repository

1. **Open the URL** in your browser (from `terraform output nxrm_url`)
2. **Login:**
   - Username: `admin`
   - Password: (from `terraform output -raw nexus_admin_password`)
3. **Set the Base URL** under **System → Capabilities → Base URL** to the URL from step 1. Nexus Repository uses it to build absolute links, for example in email notifications. It is not a `nexus.properties` setting, so the template cannot set it.

You're done! Sonatype Nexus Repository is ready to use. Change the initial admin password after the first login (it is stored in the Terraform state, see [State and Secrets](#state-and-secrets)).

---

## Reference Architectures - Detailed Specifications

| | RA-1 XSmall | RA-2 Small | RA-3 Medium | RA-4 Large | RA-5 XLarge |
|---|---|---|---|---|---|
| Nodes (`cluster_size`) | 1 | 1 | 3 | 3 | 4 |
| VM size (`vm_size`) | Standard_D4ds_v5 | Standard_D8ds_v5 | Standard_D8ds_v5 | Standard_D32ds_v5 | Standard_D48ds_v5 |
| Heap min/max (`java_min_heap`, `java_max_heap`) | 8g / 8g | 16g / 16g | 16g / 16g | 64g / 64g | 96g / 96g |
| Direct memory (`java_max_direct_memory`) | 4g | 8g | 8g | 24g | 48g |
| Data disk (`nexus_data_volume_size`) | 128 GB | 128 GB | 512 GB | 512 GB | 512 GB |
| Database (`database_type`) | H2 | PostgreSQL | PostgreSQL | PostgreSQL | PostgreSQL |
| Database SKU (`postgres_sku_name`) | - | GP_Standard_D4ds_v5 | MO_Standard_E8ds_v5 | MO_Standard_E16ds_v5 | MO_Standard_E32ds_v5 |
| Database storage (`postgres_storage_mb`) | - | 131072 MB (default) | 131072 MB (default) | 131072 MB (default) | 524288 MB |
| `postgres_max_connections` | - | 1600 | 3200 | 5000 | 5000 |
| Connection pool per node (`nxrm_connection_pool`) | 100 | 100 | 100 | 200 | 400 |
| Blob store (`blobstore_type`) | file | azure | azure | azure | azure |
| Front end | Nginx + Load Balancer | Nginx + Load Balancer | Application Gateway | Application Gateway | Application Gateway |
| HA | No | No | Yes | Yes | Yes |
| License | CE or Pro | Pro (recommended) | Pro | Pro | Pro |

### RA-1: XSmall (Temporary/Testing)

**Use Case:** Test environments, small teams, proof-of-concepts

**Configuration:**
```hcl
# tfvars/ra-1-selfmanaged.tfvars
vm_size                = "Standard_D4ds_v5"  # 4 vCPU, 16 GiB RAM
cluster_size           = 1                   # Single instance
database_type          = "h2"                # Embedded H2 database
blobstore_type         = "file"              # Local disk storage
nexus_data_volume_size = 128                 # GB
```

**Deployment time:** typically around 15 minutes; varies

**License required:** Community Edition or Pro

### RA-2: Small (Single-Instance Production)

**Use Case:** Small production deployments, single-tenant use cases

**Configuration:**
```hcl
# tfvars/ra-2-selfmanaged.tfvars
vm_size           = "Standard_D8ds_v5"      # 8 vCPU, 32 GiB RAM
cluster_size      = 1                       # Single instance
database_type     = "postgres"              # PostgreSQL Flexible Server
postgres_sku_name = "GP_Standard_D4ds_v5"   # 4 vCPU
blobstore_type    = "azure"                 # Blob Storage (or "file" for local disk)
```

**Deployment time:** typically around 20 minutes (includes database provisioning); varies

**License:** a Pro license is recommended; the template does not require one on a single node

### RA-3: Medium (High Availability)

**Use Case:** Medium production environments requiring high availability

**Configuration:**
```hcl
# tfvars/ra-3-selfmanaged.tfvars
vm_size                = "Standard_D8ds_v5"   # 8 vCPU, 32 GiB RAM each
cluster_size           = 3                    # 3-node cluster (Hazelcast)
nexus_data_volume_size = 512                  # GB per node
database_type          = "postgres"           # PostgreSQL Flexible Server
postgres_sku_name      = "MO_Standard_E8ds_v5"  # 8 vCPU, memory optimized
blobstore_type         = "azure"              # Blob Storage
```

**Features:**
- **Clustering** (Hazelcast) with the Application Gateway spreading requests across the nodes
- **Load-balanced** requests with cookie affinity

**Deployment time:** typically around 25 minutes; varies

**License required:** Pro (clustering is a Pro feature)

### RA-4: Large (High-Scale Production)

**Use Case:** Large production deployments with high transaction volumes

**Configuration:**
```hcl
# tfvars/ra-4-selfmanaged.tfvars
vm_size                = "Standard_D32ds_v5"   # 32 vCPU, 128 GiB RAM each
cluster_size           = 3                     # 3-node cluster
nexus_data_volume_size = 512                   # GB per node
database_type          = "postgres"
postgres_sku_name      = "MO_Standard_E16ds_v5"  # 16 vCPU, memory optimized
blobstore_type         = "azure"
```

**Deployment time:** typically around 25 minutes; varies

**License required:** Pro

### RA-5: XLarge (Enterprise Scale)

**Use Case:** Enterprise-scale deployments with maximum performance requirements

**Configuration:**
```hcl
# tfvars/ra-5-selfmanaged.tfvars
vm_size                = "Standard_D48ds_v5"   # 48 vCPU, 192 GiB RAM each
cluster_size           = 4                     # 4-node cluster
nexus_data_volume_size = 512                   # GB per node
database_type          = "postgres"
postgres_sku_name      = "MO_Standard_E32ds_v5"  # 32 vCPU, memory optimized
postgres_storage_mb    = 524288                # 512 GiB
nxrm_connection_pool   = 400                   # per node
blobstore_type         = "azure"
```

**Sizing guidance:** The XLarge size was validated with `MO_Standard_E32ds_v5` and a pool of 400 per node (350 is also proven for most workloads). For sustained request rates above 45,000 requests per second during spikes, a larger PostgreSQL SKU (for example `MO_Standard_E64ds_v5`) and a larger pool were needed. A larger SKU increases capacity under sudden load spikes and also cost: size it to your expected peak and budget. Keep `cluster_size` x `nxrm_connection_pool` below `postgres_max_connections`.

**Deployment time:** typically around 25 minutes; varies

**License required:** Pro

**Note:** For detailed capacity planning and sizing guidance for each Reference Architecture, see the [official Sonatype Reference Architecture documentation](https://help.sonatype.com/en/sonatype-nexus-repository-reference-architectures.html).

---

## Customization Options

### Networking

The template creates a virtual network with these defaults. Change them in `terraform.tfvars` if they overlap with networks you peer or connect to:

```hcl
# terraform.tfvars
vnet_cidr           = "10.100.0.0/16"
nodes_subnet_cidr   = "10.100.1.0/24"
db_subnet_cidr      = "10.100.3.0/24"
gateway_subnet_cidr = "10.100.4.0/24"
```

**Restrict who can reach Nexus Repository.** `ingress_cidr_blocks` lists the CIDR blocks allowed on ports 80 and 443 (port 80 only redirects to HTTPS):

```hcl
# terraform.tfvars
ingress_cidr_blocks = ["203.0.113.0/24", "198.51.100.7/32"]  # Default: ["0.0.0.0/0"]
```

> **Warning:** leaving `ingress_cidr_blocks` at its default `["0.0.0.0/0"]` allows access from the whole internet to the gateway and opens the blob store firewall. Terraform only warns during `plan`. Set it to the ranges your clients use.

`ingress_cidr_blocks` must hold public addresses: it also feeds the firewall of the blob store account (see [Storage Account Firewalls](#storage-account-firewalls)), which accepts only public IP ranges.

The VMs have no public IP addresses. Outbound traffic leaves through a NAT Gateway. To use subnets you already have, see [Bring Your Own Network](#bring-your-own-network).

**Traffic inside the virtual network.** The nodes subnet admits only the traffic the deployment needs: node to node (cluster), the Azure load balancer health probes, the Application Gateway subnet on port 8081 (clustered sizes), and SSH from the Bastion subnet when Bastion is enabled. Everything else from the virtual network, peered networks or VPN connections is denied. Shell access to the nodes is through [Azure Run Command](#node-access-with-azure-run-command-troubleshooting) or [Azure Bastion](#node-access-with-azure-bastion-optional).

### HTTPS and Certificate Renewal

The certificate and DNS settings are required (see [Prerequisites](#4-tls-certificate-and-dns-name-required)). TLS 1.2 and later only.

- **Single-node sizes (RA-1, RA-2):** Nginx on the node terminates TLS and sends `Strict-Transport-Security` (one year). A daily timer (`nxrm-cert-renew.timer`) re-reads the certificate from Key Vault and reloads Nginx when it changed; a certificate Nginx rejects is rolled back. Nexus Repository is not restarted.
- **Clustered sizes (RA-3 to RA-5):** The Application Gateway reads the certificate from Key Vault and picks up new certificate versions automatically. Use the versionless `certificate_secret_id` so new versions are found.

### Gateway Settings (clustered sizes)

```hcl
# terraform.tfvars
gateway_min_capacity            = 2    # Default; autoscale minimum, in instances
gateway_request_timeout_seconds = 900  # Default; backend request timeout in seconds
```

Application Gateway autoscale takes several minutes to add capacity. If you expect traffic spikes, set `gateway_min_capacity` for the peak you expect. The value is a number of **instances**, not capacity units: each instance reserves 10 capacity units, which are billed whether or not they are used (about $0.08 per instance-hour in East US at the time of writing, plus a fixed gateway charge; check the Azure pricing page). The autoscale maximum is 125 instances.

The gateway uses the `Standard_v2` SKU. Upgrading it to `WAF_v2` (Web Application Firewall) is an optional change outside the tested configurations; tune the WAF rules for repository traffic (large uploads, package manager clients) before you rely on them.

### Admin Password

**Default (recommended):** A secure random password is generated.

```bash
terraform output -raw nexus_admin_password
```

**Set your own** (minimum 16 characters), preferably from the environment instead of a file:
```bash
export TF_VAR_nexus_admin_password='<your-password>'
```

The admin password is used for the first start only. Change it in Nexus Repository after the first login.

### State and Secrets

**Key Vault.** The template creates its own Key Vault with Azure RBAC authorization and stores the Nexus admin password and, with PostgreSQL, the database password in it as two secrets. The vault denies all traffic except the nodes subnet (`Microsoft.KeyVault` service endpoint) and the addresses in `storage_allowed_ip_cidrs` (or the detected deployer IP), so Terraform can write the secrets. The node identity has **Key Vault Secrets User** on those two secrets only. The identity that runs Terraform gets **Key Vault Secrets Officer** on the vault, and Terraform waits 90 seconds for that role to propagate before it writes the secrets. Soft delete keeps a deleted vault for 7 days; `terraform destroy` purges it so the name can be reused.

The Terraform state contains the admin and database passwords and, when Terraform generated it, the SSH private key. Use an encrypted remote backend (for example an Azure Storage backend with restricted access), limit who can read the state, and prefer `TF_VAR_nexus_admin_password` and `TF_VAR_db_password` over writing passwords into a tfvars file.

### SSH Key

```hcl
# terraform.tfvars
admin_ssh_public_key = "ssh-ed25519 AAAA... you@example.com"
```

If `admin_ssh_public_key` is empty, Terraform generates a key pair and stores the private key in the Terraform state (`terraform output -raw generated_ssh_private_key`). Protect your state file. Prefer setting your own public key.

### Storage Options

#### Blob Storage

**Azure Blob Storage (default for RA-2 through RA-5, required for clusters):** Nexus Repository reaches the storage account with a managed identity. No storage keys are stored on the nodes.

```hcl
# terraform.tfvars
blobstore_type = "azure"
```

**Local disk (RA-1 and RA-2 only):** Nexus Repository keeps its default file blob store on the data disk.
```hcl
# terraform.tfvars
blobstore_type         = "file"
nexus_data_volume_size = 500  # GB; blobs live on the data disk
```

#### Data Disk

```hcl
# terraform.tfvars
nexus_data_volume_type = "PremiumV2_LRS"  # Default
# nexus_data_volume_type = "Premium_LRS"
```

`PremiumV2_LRS` (Premium SSD v2) requires a region and availability zone that support it. If your region or zone does not, use `Premium_LRS`. Set `zone` to choose the availability zone of the nodes and disks.

#### Storage Account Firewalls

**Installer account** (installer, license): restricted to your deployer IP and the node subnet. List the public IP of the machine that runs Terraform in `storage_allowed_ip_cidrs`. A later `plan` or `destroy` from a different public IP gets `403` when Terraform refreshes the uploaded blobs, so run it from the listed address or add the new one:

```hcl
# terraform.tfvars
storage_allowed_ip_cidrs = ["203.0.113.10"]
```

*Optional lookup:* `detect_deployer_ip = true` makes the template look up your public IP address on `https://api.ipify.org` during `plan` and `apply` and add it for you. It is off by default because many environments do not allow Terraform runs to call a third-party service.

If your public IP has already changed, `plan` and `apply` stop at the refresh with `403` on the installer blobs. Run `terraform apply -refresh=false` once: it updates the firewall rules to your current IP (with `detect_deployer_ip = true`), and later runs work normally. If your IP changes often, list a stable range in `storage_allowed_ip_cidrs`.

**Security of the two accounts.** Both storage accounts keep Shared Key access enabled, because the Terraform `azurerm` provider uses it for data-plane checks and for the uploads to the installer account. Nexus Repository itself authenticates to the blob store with the VM managed identity and neither uses nor stores an account key; Direct Download then uses user delegation signed URLs. For both accounts the network firewall, private containers, HTTPS with TLS 1.2 as the minimum and the refusal of public blob access apply. The installer account holds only the installer and the license. The Nexus blob store account keeps soft delete on for blobs and containers (7 days), so deleted blobs and containers can be recovered during that window. Soft delete does not protect the account itself, and the template sets no versioning, backup or resource lock: add them according to your recovery needs.

*Optional hardening:* if your policy requires Shared Key access to be disabled, do it after deployment, and only together with `storage_use_azuread = true` in the `azurerm` provider block and the **Storage Blob Data Contributor** role for the deploying identity on the accounts. Otherwise later `plan` and `apply` runs fail with `KeyBasedAuthenticationNotPermitted`.

**Blob store account** (RA-2 to RA-5 with `blobstore_type = "azure"`): clients download artifacts straight from the blob endpoint, because Nexus Repository answers a download with a redirect to a short-lived signed URL. The account network rule therefore follows `ingress_cidr_blocks`:
- `ingress_cidr_blocks` contains `0.0.0.0/0` (default): the account accepts all networks. The container stays private, HTTPS with TLS 1.2 only, and anonymous access is refused: a request needs Entra ID, a signed URL or an account key. Signed URLs are bearer tokens with a short lifetime (about 5 minutes by default): anyone holding a URL can use it until it expires.
- Otherwise: the account denies by default and allows the `ingress_cidr_blocks`, the node subnet and the deployer IP.

**Clients in the same Azure region.** Azure Storage IP rules do not apply to requests that come from the same region as the storage account. A client hosted in Azure in that region and listed in `ingress_cidr_blocks` gets `403` on Direct Download when the account is in deny mode. Choose one:
- Allow all networks by including `0.0.0.0/0` in `ingress_cidr_blocks` (anonymous access is still refused).
- List the client subnets in `blob_client_subnet_ids`. Each subnet needs the `Microsoft.Storage` service endpoint. They are ignored in allow mode and with private endpoints.
- Use [private endpoints](#private-endpoint-for-the-blob-store) (`use_private_endpoints = true`).

```hcl
# terraform.tfvars
blob_client_subnet_ids = ["/subscriptions/<subscription-id>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet>/subnets/<clients>"]
```

### Database

PostgreSQL is used for RA-2 through RA-5.

```hcl
# terraform.tfvars
postgres_sku_name              = "MO_Standard_E8ds_v5"
postgres_storage_mb            = 131072
postgres_version               = "16"
postgres_backup_retention_days = 7
nxrm_connection_pool           = 100
```

**Zone-redundant high availability (optional):**
```hcl
# terraform.tfvars
postgres_zone_redundant_ha = false  # Default
```

Implementing multi-AZ is optional, depending on the customer setup, and is outside the tested configurations.

**Passwords:** `db_password` is generated if not set (minimum 16 characters if you set it). The database server name gets a random suffix because it is a global DNS name.

The server storage grows automatically when it fills up (`auto_grow_enabled`), and the IOPS of Premium SSD storage scale with its size, so raise `postgres_storage_mb` if the database needs more IOPS. Do not set `postgres_max_connections` lower than the size tfvars value. Clusters need one pool per node.

### JVM Settings

```hcl
# terraform.tfvars
java_min_heap          = "16g"
java_max_heap          = "16g"
java_max_direct_memory = "8g"
```

Keep the heap and direct memory consistent with the VM memory. The size tfvars files contain tested values.

---

## Bring Your Own Network

By default the template creates its own virtual network. To deploy into subnets that already exist (for example a hub-and-spoke landing zone), set `create_network = false` and pass the subnet IDs. The template then creates no virtual network, subnet, NAT gateway, public IP for NAT, network security group or association, and never changes the ones you own. `terraform destroy` removes only what the template created.

```hcl
# terraform.tfvars
create_network    = false
nodes_subnet_id   = "/subscriptions/<subscription-id>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet>/subnets/<nodes>"
db_subnet_id      = "/subscriptions/<subscription-id>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet>/subnets/<db>"       # RA-2 to RA-5 (PostgreSQL)
gateway_subnet_id = "/subscriptions/<subscription-id>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet>/subnets/<gateway>"  # RA-3 to RA-5 (cluster)
bastion_subnet_id = "/subscriptions/<subscription-id>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet>/subnets/AzureBastionSubnet"  # only with enable_bastion
```

| Variable | Required when |
|---|---|
| `nodes_subnet_id` | always with `create_network = false` |
| `db_subnet_id` | `database_type = "postgres"` |
| `gateway_subnet_id` | `cluster_size > 1` |
| `bastion_subnet_id` | `enable_bastion = true` |

All subnets must be in the same virtual network. The `*_subnet_cidr` and `vnet_cidr` variables are ignored. Setting any subnet ID with `create_network = true` is rejected. The `azure/examples/existing-network` folder builds a ready-made network that meets every requirement below; use it to try the mode or as a reference.

### Requirements for your subnets

| Subnet | Requirement |
|---|---|
| Nodes | Service endpoints `Microsoft.Storage` and `Microsoft.KeyVault` (the nodes read their passwords from Key Vault; the template checks this and stops with a message naming the missing endpoint). Outbound access to the Oracle Linux package repositories, the storage accounts, Key Vault, the instance metadata service `169.254.169.254` and Microsoft Entra ID (a NAT gateway or your firewall). |
| Database | Empty, dedicated, delegated to `Microsoft.DBforPostgreSQL/flexibleServers`. Declare the delegation action `Microsoft.Network/virtualNetworks/subnets/join/action` so Terraform sees no drift. The template cannot verify the delegation: a missing delegation fails at apply time. |
| Gateway | Dedicated to the Application Gateway (nothing else in it). |
| Bastion | Named `AzureBastionSubnet`, at least /26. |

### Network security group rules

The template does not edit network security groups it does not own. If your subnets have NSGs, they must allow:

| Subnet | Direction | Source | Port | Purpose |
|---|---|---|---|---|
| Nodes | Inbound | Gateway subnet (clusters) or your clients (single node) | 8081 (clusters), 80 and 443 (single node) | Client and gateway traffic |
| Nodes | Inbound | Nodes subnet | all | Node to node (cluster, Hazelcast) |
| Nodes | Inbound | `AzureLoadBalancer` | all | Health probes |
| Nodes | Inbound | Bastion subnet | 22 | Only with Bastion |
| Gateway | Inbound | Your clients | 80 and 443 | Client traffic |
| Gateway | Inbound | `GatewayManager` | 65200-65535 | Gateway management (blocking it breaks the gateway) |
| Gateway | Inbound | `AzureLoadBalancer` | all | Health probes |
| Gateway | Outbound | Nodes subnet | 8081 | Backend traffic |

A ready-to-paste example lives in `azure/examples/existing-network/main.tf` (the `azurerm_network_security_rule` resources).

### Node IP addresses

In a template-created network the nodes get the static addresses `.10`, `.11`, ... of the nodes subnet. In an existing subnet Azure assigns the addresses, because those fixed addresses may already be in use. To choose them yourself:

```hcl
# terraform.tfvars (one address per node, free addresses inside the nodes subnet)
node_private_ips = ["10.50.1.20", "10.50.1.21", "10.50.1.22"]
```

### Central private DNS zone for PostgreSQL

By default the template creates the private DNS zone `privatelink.postgres.database.azure.com` and links it to the virtual network. If your organization manages that zone centrally, pass its ID and the template creates neither the zone nor the link:

```hcl
# terraform.tfvars
postgres_private_dns_zone_id = "/subscriptions/<subscription-id>/resourceGroups/<dns-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.postgres.database.azure.com"
```

The virtual network must already be linked to that zone, and the identity that runs Terraform needs the **Private DNS Zone Contributor** role on it (Azure registers the server in the zone when the server is created).

### Private front end

By default clients reach Nexus Repository through a public IP address. For internal-only access:

```hcl
# terraform.tfvars
frontend_visibility = "private"
private_frontend_ip = "10.50.4.20"   # optional for RA-1 and RA-2, required for RA-3 to RA-5
```

- **RA-1 and RA-2:** the Standard load balancer gets a private address in the nodes subnet (the one you set, or an address Azure assigns) instead of a public IP.
- **RA-3 to RA-5:** the Application Gateway listeners attach to a private address in the gateway subnet. Azure Application Gateway v2 keeps a public IP resource for its own management, but it has no listener: nothing is served on it. A fully private gateway (no public IP at all) needs a subscription feature registration (`EnableApplicationGatewayNetworkIsolation`) and a subnet delegation, and is not implemented by this template. The address must be free in the gateway subnet.
- Network security groups created by the template deny sources tagged `Internet` on ports 80 and 443. For NSGs you own, add that rule yourself.
- `front_end_public_ip` is empty; read `terraform output private_frontend_ip_address` instead.
- The template creates no DNS record in private mode, and `dns_zone_name` cannot be combined with it. Create a record for `dns_name` in your private DNS zone that points at `private_frontend_ip_address`, and make sure clients reach the virtual network (peering, VPN or ExpressRoute).
- The TLS certificate must still match `dns_name`.
- With a private front end, `ingress_cidr_blocks` normally holds private ranges. The storage firewalls reject private ranges, so the template leaves them out: the blob store account then admits only the nodes subnet, the deployer IP and any public ranges you list. Clients in other private networks that follow Direct Download redirects need `use_private_endpoints = true`, or the public egress IPs of those networks listed in `ingress_cidr_blocks`.

### Private endpoint for the blob store

With `blobstore_type = "azure"` you can remove the public path to the Nexus blob store account:

```hcl
# terraform.tfvars
use_private_endpoints    = true
blob_private_dns_zone_id = "/subscriptions/<subscription-id>/resourceGroups/<dns-rg>/providers/Microsoft.Network/privateDnsZones/privatelink.blob.core.windows.net"  # optional
```

The template then creates a private endpoint (`blob`) in the nodes subnet, disables public network access on the account and, unless you pass a central zone, creates the zone `privatelink.blob.core.windows.net` linked to the virtual network. With a central zone, the identity that runs Terraform needs **Private DNS Zone Contributor** on it and the virtual network must be linked to it.

Be aware of two effects:
- **Direct Download clients.** Nexus Repository answers a download with a redirect to a signed URL on the blob endpoint. Every client must resolve that name to the private endpoint and reach it (same virtual network, peering, VPN or ExpressRoute with private DNS). Clients outside the network cannot download.
- **Installer account unchanged.** The account with the installer and license keeps its firewall and the deployer IP allow-list, because Terraform uploads to it from where you run it. The blob store account needs no data-plane access from your machine (containers are created through Azure Resource Manager), so `terraform apply` from outside the network keeps working.

The Key Vault private endpoint for the TLS certificate is yours to create; the template only needs the identity to read the secret. The vault the template creates for the passwords is reached through the nodes subnet service endpoint, not a private endpoint.

## DNS Setup (Custom Domain)

### Option 1: Terraform Creates the Record

```hcl
# terraform.tfvars
dns_name                = "nexus.example.com"
dns_zone_name           = "example.com"
dns_zone_resource_group = "my-dns-rg"
```

The zone must already exist. Terraform adds only the A record (TTL 300 s).

### Option 2: Create the Record Yourself

```bash
terraform output front_end_public_ip
```

Create an A record from `dns_name` to that address at your DNS provider. Then check it:

```bash
nslookup nexus.example.com
```

DNS changes can take a few minutes to propagate. Until the record exists, browsers cannot reach the name, and the certificate does not match the bare IP address.

---

## Accessing Nexus Repository

### Web Interface

1. Get the URL: `terraform output nxrm_url`
2. Open it in your browser.
3. Log in as `admin` with the password from `terraform output -raw nexus_admin_password`.
4. Set the Base URL under **System → Capabilities → Base URL** to that URL.

### Node Access with Azure Run Command (Troubleshooting)

The nodes have no public IP addresses and no inbound SSH from the internet. Use Azure Run Command, which needs no extra resources:

```bash
RG=$(terraform output -raw resource_group_name)

# List the nodes (named nxrm-<environment_name>-node-0, -node-1, ...)
az vm list -g "$RG" --query "[].name" -o tsv

# Check the Nexus Repository service status
az vm run-command invoke -g "$RG" -n <node-name> \
  --command-id RunShellScript --scripts "systemctl status nexus --no-pager"

# View the last lines of the Nexus Repository log
az vm run-command invoke -g "$RG" -n <node-name> \
  --command-id RunShellScript \
  --scripts "tail -n 100 /opt/sonatype/sonatype-work/nexus3/log/nexus.log"

# Check if Nexus Repository is responding locally
az vm run-command invoke -g "$RG" -n <node-name> \
  --command-id RunShellScript \
  --scripts "curl -s -o /dev/null -w '%{http_code}' http://127.0.0.1:8081/service/rest/v1/status"
```

Run Command is non-interactive, and the output of the action form is limited to 4 KB. Use `tail` or `grep` to keep output short.

### Node Access with Azure Bastion (Optional)

Enable Bastion when you need an interactive shell on the private nodes (thread dumps, log tails):

```hcl
# terraform.tfvars
enable_bastion             = true
bastion_sku                = "Standard"
bastion_user_principal_ids = ["<entra-id-object-id-of-a-user-or-group>"]
```

**Cost:** Bastion bills hourly from deployment. East US list prices: Basic $0.19, Standard $0.29, Premium $0.45 per hour. Check current prices for your region.

**SKU and connection method:** `az network bastion ssh` (native client) needs tunneling, which requires `bastion_sku` = "Standard" or "Premium". The Basic SKU works only through the browser-based connection in the Azure portal.

**Advantages:** no public IP addresses or inbound SSH on the VMs, TLS on port 443, Entra ID sign-in, and an audit trail.

Users listed in `bastion_user_principal_ids` get the **Virtual Machine Administrator Login** role on the resource group, which gives them `sudo` on every VM in it. Connect with:

```bash
az network bastion ssh --name nxrm-<environment_name>-bastion --resource-group "$(terraform output -raw resource_group_name)" \
  --target-resource-id <vm-resource-id> --auth-type AAD
```

---

## Troubleshooting

### Issue: Plan stops with a missing service endpoint (existing network)

The nodes subnet needs the `Microsoft.Storage` service endpoint and the `Microsoft.KeyVault` service endpoint. Add them to the subnet, or the storage and Key Vault firewalls reject the nodes. See [Requirements for your subnets](#requirements-for-your-subnets).

### Issue: Cannot reach a private front end

Check, in order: your client reaches the virtual network (peering, VPN or ExpressRoute); `dns_name` resolves to `terraform output private_frontend_ip_address` from the client; the NSGs you own allow 80/443 from the client (see [Network security group rules](#network-security-group-rules)).

### Issue: Downloads fail after enabling private endpoints

Direct Download redirects clients to the blob endpoint. From the failing client, `nslookup <account>.blob.core.windows.net` must return a private address (the private endpoint). If it returns a public one, link the client's DNS to the `privatelink.blob.core.windows.net` zone.

### Issue: "Cannot reach Nexus Repository at the URL"

**Possible causes:**

1. **DNS does not point at the front end**
   **Solution:** Compare `terraform output front_end_public_ip` with `nslookup <dns_name>`. Create or fix the A record.

2. **Nexus Repository is still starting up**
   The first boot installs and starts Nexus Repository after the VM is created; clustered nodes then join the cluster.

   **Solution:** Wait a few minutes and try again. Check startup progress:
   ```bash
   RG=$(terraform output -raw resource_group_name)
   az vm run-command invoke -g "$RG" -n <node-name> --command-id RunShellScript \
     --scripts "systemctl status nexus --no-pager; tail -n 30 /opt/sonatype/sonatype-work/nexus3/log/nexus.log"
   ```

3. **Your address is not in the ingress allow-list**
   **Solution:** Check `ingress_cidr_blocks` in `terraform.tfvars` and add your address range.

4. **Gateway backend health failing (clustered sizes)**
   ```bash
   RG=$(terraform output -raw resource_group_name)
   az network application-gateway show-backend-health -g "$RG" -n nxrm-<environment_name>-gw
   ```

   The gateway probes `/service/rest/v1/status` on port 8081. **If unhealthy:** check `systemctl status nexus` and the log on that node (see above).

### Issue: "403 Forbidden" or "Invalid credentials"

**Cause:** Wrong admin password or password copied incorrectly.

**Solution:**
```bash
# Display the password (careful if screen sharing)
terraform output -raw nexus_admin_password
```

Copy it exactly, with no extra spaces or newlines.

### Issue: Certificate errors

**Symptoms:** The browser warns about the certificate, the gateway fails to apply, or the Nginx certificate timer reports `Key Vault HTTP 403`.

**Check:**
- `certificate_secret_id` is the **secret** URI (`.../secrets/<name>`) of a Key Vault **certificate**, without a version
- The Key Vault uses **Azure RBAC authorization**, and `certificate_key_vault_id` is that vault's resource ID
- The certificate covers `dns_name` and has not expired
- Role assignments can take a few minutes to propagate. On a clustered size, re-run `terraform apply`.
- On a single-node size, the first boot retries the certificate for about 10 minutes and then stops the bootstrap before Nexus Repository starts. Check `/var/log/nxrm-bootstrap.log` (see [First boot](#issue-first-boot-is-slow-or-nexus-repository-did-not-start)), fix the access, and re-run the deployment by replacing the VM: `terraform apply -replace='module.compute.azurerm_linux_virtual_machine.node[0]'`.

After the first boot you can run the refresh manually on single-node sizes:
```bash
RG=$(terraform output -raw resource_group_name)
az vm run-command invoke -g "$RG" -n <node-name> --command-id RunShellScript \
  --scripts "/usr/local/sbin/nxrm-cert-renew.sh"
```

### Issue: "a resource with the ID ... already exists" after a failed apply

An apply can fail with `HTTP response was nil; connection may have been reset` even though Azure created the resource. The next `apply` then stops with `a resource with the ID "..." already exists - to be managed via Terraform this resource needs to be imported`.

**Solution:** delete only the resource named in the error, which the failed apply created, in the Azure portal or with `az`, and run `terraform apply` again. Importing it often fails while other values are still unknown.

### Issue: OS disk error 409 when creating the VM

**Cause:** The OS disk is smaller than the VM image requires.

**Solution:** Keep `os_disk_size_gb` at 64 or larger (the default).

### Issue: Premium SSD v2 errors (region or zone)

**Symptoms:** `terraform apply` fails when creating the data disk with a message about `PremiumV2_LRS` not being supported in the region or availability zone.

**Solution:** Choose a region and `zone` that support Premium SSD v2, or use `Premium_LRS`:
```hcl
# terraform.tfvars
nexus_data_volume_type = "Premium_LRS"
```

### Issue: First boot is slow or Nexus Repository did not start

The VM runs a bootstrap through cloud-init on first boot: it installs Nexus Repository, mounts the data disk, and creates the blob store. Read its log:

```bash
RG=$(terraform output -raw resource_group_name)
az vm run-command invoke -g "$RG" -n <node-name> --command-id RunShellScript \
  --scripts "tail -n 40 /var/log/nxrm-bootstrap.log"
```

**SELinux note:** The nodes keep SELinux in enforcing mode. Only if Nexus Repository fails to start with `203/EXEC` does the bootstrap switch SELinux to permissive, and it logs a `WARNING` line in `/var/log/nxrm-bootstrap.log`. Search for it with `grep WARNING /var/log/nxrm-bootstrap.log`.

### Issue: Database connection errors in logs

**Symptoms:** Nexus Repository logs show connection failures to the PostgreSQL database.

**Check:**
```bash
RG=$(terraform output -raw resource_group_name)
az vm run-command invoke -g "$RG" -n <node-name> --command-id RunShellScript \
  --scripts "grep -v password /opt/sonatype/sonatype-work/nexus3/etc/fabric/nexus-store.properties"
terraform output database_fqdn
```

**Solution:** The database is reachable only from inside the virtual network. Make sure the host in `nexus-store.properties` matches `database_fqdn`. If `db_password` was changed after the first deployment, the password stored on the node is outdated; redeploy.

### Issue: Out of disk space

**Check volume usage:**
```bash
RG=$(terraform output -raw resource_group_name)
az vm run-command invoke -g "$RG" -n <node-name> --command-id RunShellScript \
  --scripts "df -h /opt/sonatype; du -sh /opt/sonatype/sonatype-work"
```

**Solution:** Increase the data disk in terraform.tfvars:
```hcl
nexus_data_volume_size = 500   # Increase from 128 GB
```

Then run `terraform apply`. Terraform grows the Azure managed disk only; it does not grow the filesystem. Depending on the disk type, growing it may require the VM to be deallocated, so review the plan before applying.

After the apply, grow the ext4 filesystem on each node. It sits directly on the whole data disk (`/dev/disk/azure/scsi1/lun0`), without a partition:
```bash
RG=$(terraform output -raw resource_group_name)
az vm run-command invoke -g "$RG" -n <node-name> --command-id RunShellScript \
  --scripts "resize2fs /dev/disk/azure/scsi1/lun0; df -h /opt/sonatype"
```

`df -h /opt/sonatype` should now show the larger size. Blob Storage grows on its own.

### Issue: "License file required for clustered deployments"

**Symptoms:** Terraform validation fails with a message about a missing license file.

**Solution:** Clustered deployments (RA-3+) require a paid Sonatype Nexus Repository Pro license:
```bash
# Place your Pro license file
cp your-license.lic files_to_upload_to_nodes/

# Verify it's present
ls -lh files_to_upload_to_nodes/*.lic
```

---

## Cleanup

To destroy all resources and stop incurring Azure charges:

```bash
terraform destroy
```

**⚠️ WARNING:** This action permanently deletes:
- All virtual machines and their managed disks
- The PostgreSQL server including all data
- The Storage account and all stored artifacts (permanently: soft delete does not cover a deleted account), and the Key Vault with the generated passwords
- The load balancer or Application Gateway, NAT Gateway, public IP addresses, and the virtual network
- The managed identity, network security groups, and Bastion (if enabled)
- The DNS A record, if Terraform created it

**Not touched:** your certificate, your own Key Vault (only the role assignment Terraform added is removed), and your Azure DNS zone.

**This action is irreversible.** Before destroying production environments:

1. **Export critical data:**
   - Back up the PostgreSQL database using your organization's procedure (for example `pg_dump` from a host inside the virtual network, host from `terraform output database_fqdn`)
   - Copy important artifacts from the `nxrm-blobs` container of the blob store account. It has no Terraform output: it is the second storage account in the resource group (`az storage account list -g "$(terraform output -raw resource_group_name)" -o table`); `artifacts_account_name` is the installer account

2. **Document configurations:**
   - Export Terraform state: `terraform state pull > terraform.tfstate.backup`
   - Document any custom Nexus Repository configurations
   - Save admin credentials

3. **Verify backups** before proceeding with destroy

**Verify cleanup:** `az resource list -g <resource-group> -o table` should return nothing afterwards.

---

## Additional Resources

- **[Sonatype Nexus Repository Documentation](https://help.sonatype.com/en/sonatype-nexus-repository.html)** - Official product documentation
- **[Reference Architecture Guide](https://help.sonatype.com/en/sonatype-nexus-repository-reference-architectures.html)** - Detailed RA specifications and sizing guidance
- **[Terraform AzureRM Provider](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs)** - Azure resource documentation
- **[Azure Well-Architected Framework](https://learn.microsoft.com/en-us/azure/well-architected/)** - Best practices for cloud architecture

---

## License

Copyright (c) 2008-present Sonatype, Inc.

All rights reserved. Includes third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions

---

## Support and Responsibility

**This Terraform template is provided as-is to help you deploy Sonatype Nexus Repository infrastructure on Azure.** While this template simplifies the deployment process, please understand:

**You (the customer) are solely responsible for:**
- All Azure costs incurred by deployed resources
- Deployment, configuration, and maintenance of your Nexus Repository infrastructure
- Security hardening and compliance requirements specific to your organization
- Monitoring, updates, and patches to your deployment
- Backup and disaster recovery procedures
- Scaling and performance optimization for your workloads
- Troubleshooting and resolving infrastructure issues

**Sonatype provides:**
- This template as a starting point for Nexus Repository infrastructure deployment
- Official Nexus Repository documentation and product support (for Pro customers)
- General guidance on Reference Architecture best practices

**Sonatype does NOT provide:**
- Tailored Terraform templates customized for your specific environment
- Infrastructure management or DevOps services
- Azure cost management or optimization services
- Custom modifications to this Terraform code

**For Sonatype Nexus Repository Pro customers:** While we do not provide custom Terraform development, our support team can offer guidance on Nexus Repository configuration, sizing, and best practices. For infrastructure-specific questions, please consult your internal DevOps or cloud teams, or engage an Azure partner for professional services.

**Questions about this template?** Open an issue in this repository.

**Questions about Sonatype Nexus Repository features?** Contact [Sonatype Support](https://support.sonatype.com) if you are a Pro customer.
