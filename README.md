# Sonatype Nexus Repository Infrastructure as Code - AWS Reference Architectures

This repository provides pre-configured reference architectures for small, mid-sized, and large-scale enterprise deployments to enable you to deploy Sonatype Nexus Repository on AWS using Terraform. 

## ⚠️ Cost and Responsibility Disclaimer

**IMPORTANT:** Deploying this infrastructure will incur AWS charges including compute (EC2, RDS), storage (S3, EBS), networking (Load Balancer, NAT Gateway, data transfer), and other AWS services. AWS costs vary by region, instance types, data transfer volumes, and usage patterns.

**You are solely responsible for:**
- Monitoring and managing all AWS costs associated with deployed resources
- Understanding AWS pricing before deployment
- Cleaning up resources when no longer needed to avoid ongoing charges
- Reviewing and optimizing your deployment for cost efficiency

**Sonatype provides this template as-is to help you deploy Nexus Repository infrastructure but bears no responsibility for any AWS costs you incur.** Use AWS Cost Explorer and billing alerts to track your spending.

---

## What This Provides

- **5 Reference Architecture sizes** (extra-small, small, medium, large, and extra-large) with pre-tuned configurations
- **High Availability (HA)** support with multi-node clustering in reference architectures 3–5 (i.e., medium through extra-large with a paid Pro license)
- **PostgreSQL or H2 database options** H2 only available for size extra-small; note that PostgreSQL is highly recommended for all deployments and required for HA deployments
- **S3 or EBS blob storage** EBS can only be used with the extra-small and small architectures; sizes small through extra-large default to using S3, and S3 is required for HA deployments
- **Application Load Balancer** with HTTPS support
- **Automated password management** via Terraform outputs
- **Security features** including encrypted storage (S3/EBS), private subnets for instances, and IMDSv2 enforcement
- **One-command deployment** with minimal configuration required

It is important to choose the correct reference architecture for your organization's needs. AWS reference architecture documentation to help you choose the appropriate architecture size is available in Sonatype's help documentation under [Sonatype Platform AWS Reference Architectures](https://help.sonatype.com/en/aws-reference-architectures.html).

---

## Prerequisites

### 1. AWS Account Setup

**Required AWS permissions:**
- EC2 (instances, security groups, key pairs)
- VPC (if creating new network)
- S3 (blob storage, installer artifacts)
- RDS (PostgreSQL for RA-2+)
- Elastic Load Balancing (Application Load Balancer)
- IAM (instance roles and policies)
- Certificate Manager (for HTTPS)

**Recommended:** Use an IAM user or role with `PowerUserAccess` policy for initial setup.

### 2. Tools Installation

```bash
# Terraform >= 1.11.2 (older versions may work but have not been tested)
terraform version

# AWS CLI configured with credentials
aws sts get-caller-identity

# jq (for parsing JSON outputs)
which jq
```

### 3. Nexus Repository Installer Files

**Download the installer:**
1. Go to [Sonatype Help Center](https://help.sonatype.com/en/download.html)
    - Make sure to download a version matching the EC2 nodes' system architecture (default for the tfvars files is arm64).
2. Download the **Unix/Linux (.tar.gz)** version
3. Download your **Pro license file** (.lic) if using Pro features

**Place files in the folder:**
```bash
# Navigate to the iac-nxrm-ra folder
cd iac-nxrm-ra

# Copy installer (any filename starting with 'nexus' and ending with '.tar.gz')
cp ~/Downloads/nexus-*.tar.gz files_to_upload_to_nodes/

# Copy license file (optional - required for RA-2+)
cp ~/Downloads/your-license.lic files_to_upload_to_nodes/

# Verify files are present
ls -lh files_to_upload_to_nodes/
```

**Expected files:**
```
files_to_upload_to_nodes/
├── nexus-3.90.2-unix.tar.gz     (your installer)
├── your-license.lic              (optional, required for RA-2+)
└── README.md
```

### 4. ACM Certificate (Optional but Recommended)

For HTTPS access, create an SSL/TLS certificate in AWS Certificate Manager:

1. Open [AWS Certificate Manager](https://console.aws.amazon.com/acm)
2. **Request a certificate**
3. Choose **Request a public certificate**
4. Enter your domain (e.g., `nexus.yourdomain.com` or `*.yourdomain.com` for wildcard)
5. Choose **DNS validation** (recommended) or **Email validation**
6. Complete validation process
7. Copy the certificate ARN (e.g., `arn:aws:acm:us-east-1:123456789:certificate/abc-123`)

**Without a certificate:** Deployment will use HTTP only (not recommended for production).

---

## Quick Start (5 Minutes to Deploy)

### Step 1: Choose Your Reference Architecture

| RA Size | Use Case | Compute | License | Database | Storage | HA |
|---------|----------|---------|---------|----------|---------|-----|
| **RA-1 (XSmall)** | Dev/Test | 1x m7g.xlarge | CE or Pro | H2 | EBS | No |
| **RA-2 (Small)** | Small Prod | 1x m7g.2xlarge | Pro | PostgreSQL | S3 or EBS | No |
| **RA-3 (Medium)** | Medium Prod | 3x m7g.2xlarge | Pro | PostgreSQL | S3 | Yes |
| **RA-4 (Large)** | Large Prod | 3x m7g.8xlarge | Pro | PostgreSQL | S3 | Yes |
| **RA-5 (XLarge)** | Enterprise | 4x m7g.12xlarge | Pro | PostgreSQL | S3 | Yes |

**For this example, we'll deploy RA-1 (XSmall).**

### Step 2: Configure Your Deployment

```bash
# Copy the RA-1 template
cp tfvars/ra-1-selfmanaged.tfvars terraform.tfvars

# Edit the configuration
nano terraform.tfvars  # or vim, code, etc.
```

**Minimal configuration (required):**
```hcl
# terraform.tfvars

# AWS region for deployment
aws_region = "us-east-1"

# (Optional) ACM certificate for HTTPS
# alb_certificate_arn = "arn:aws:acm:us-east-1:ACCOUNT:certificate/CERT_ID"
```

**That's it!** All other settings have sensible defaults. See [Customization Options](#customization-options) for advanced configuration.

### Step 3: Deploy

```bash
# Initialize Terraform (first time only)
terraform init

# Preview what will be created
terraform plan

# Deploy (takes ~10-15 minutes)
terraform apply
```

**Terraform will create:**
- VPC with public/private subnets across multiple availability zones (or use your existing VPC)
- EC2 instance(s) running Nexus Repository
- Application Load Balancer for HTTPS access
- S3 bucket for blob storage (or EBS volumes depending on configuration)
- RDS PostgreSQL database (RA-2 and above)
- Security groups, IAM roles, SSH keys

### Step 4: Get Your Access Information

After deployment completes, retrieve your credentials:

```bash
# Get the Nexus Repository URL
terraform output nxrm_url

# Get the admin password
terraform output -raw nexus_admin_password
```

**Example output:**
```
nxrm_url = "https://nxrm-20260324.us-east-1.elb.amazonaws.com"
Admin password: XH8f#kL2-pW9@mR4+qT6
```

### Step 5: Access Nexus Repository

1. **Open the URL** in your browser (from `terraform output nxrm_url`)
2. **Login:**
   - Username: `admin`
   - Password: (from `terraform output -raw nexus_admin_password`)

You're done! Sonatype Nexus Repository is ready to use.

---

## Reference Architectures - Detailed Specifications

### RA-1: XSmall (Temporary/Testing)

**Use Case:** Test environments, small teams, proof-of-concepts

**Configuration:**
```hcl
# tfvars/ra-1-selfmanaged.tfvars
instance_type          = "m7g.xlarge"     # 4 vCPU, 16 GiB RAM
cluster_size           = 1                # Single instance
database_type          = "h2"             # Embedded H2 database
blobstore_type         = "file"           # Local EBS storage
nexus_data_volume_size = 200              # GB
nexus_blob_volume_size = 200              # GB
```

**Deployment time:** ~10 minutes

**License required:** Community Edition or Pro

### RA-2: Small (Single-Instance Production)

**Use Case:** Small production deployments, single-tenant use cases

**Configuration:**
```hcl
# tfvars/ra-2-selfmanaged.tfvars
instance_type          = "m7g.2xlarge"    # 8 vCPU, 32 GiB RAM
cluster_size           = 1                # Single instance
database_type          = "postgres"       # RDS PostgreSQL
blobstore_type         = "s3"             # S3 bucket (or "file" for EBS)
```

**Deployment time:** ~12 minutes (includes RDS provisioning)

**License required:** Pro

### RA-3: Medium (High Availability)

**Use Case:** Medium production environments requiring high availability

**Configuration:**
```hcl
# tfvars/ra-3-selfmanaged.tfvars
instance_type = "m7g.2xlarge"     # 8 vCPU, 32 GiB RAM each
cluster_size  = 3                 # 3-node cluster (Hazelcast)
database_type = "postgres"        # RDS Multi-AZ
blobstore_type = "s3"             # S3 bucket
```

**Features:**
- **Zero-downtime deployments** (rolling updates across cluster nodes)
- **Automatic failover** (Hazelcast clustering)
- **Load-balanced** requests across all nodes

**Deployment time:** ~15 minutes

**License required:** Pro (clustering is a Pro feature)

### RA-4: Large (High-Scale Production)

**Use Case:** Large production deployments with high transaction volumes

**Configuration:**
```hcl
# tfvars/ra-4-selfmanaged.tfvars
instance_type = "m7g.8xlarge"     # 32 vCPU, 128 GiB RAM each
cluster_size  = 3                 # 3-node cluster
database_type = "postgres"
blobstore_type = "s3"
```

**Deployment time:** ~15 minutes

**License required:** Pro

### RA-5: XLarge (Enterprise Scale)

**Use Case:** Enterprise-scale deployments with maximum performance requirements

**Configuration:**
```hcl
# tfvars/ra-5-selfmanaged.tfvars
instance_type = "m7g.12xlarge"    # 48 vCPU, 192 GiB RAM each
cluster_size  = 4                 # 4-node cluster
database_type = "postgres"
blobstore_type = "s3"
```

**Deployment time:** ~20 minutes

**License required:** Pro

**Note:** For detailed capacity planning, performance characteristics, and sizing guidance for each Reference Architecture, see the [official Sonatype Reference Architecture documentation](https://help.sonatype.com/en/sonatype-platform-reference-architectures.html).

---

## Customization Options

### Networking

#### Option 1: Create New VPC (Default)

Terraform automatically creates a production-ready VPC:
- Public and private subnets across 2+ availability zones
- NAT gateways for private subnet internet access
- Internet gateway for ALB public access

```hcl
# terraform.tfvars (this is the default, no configuration needed)
create_vpc = true
```

#### Option 2: Use Existing VPC (BYOV)

Deploy into your existing network infrastructure:

```hcl
# terraform.tfvars
create_vpc        = false
vpc_id            = "vpc-0123456789abcdef"
subnet_ids        = ["subnet-private1", "subnet-private2"]   # Private subnets for EC2 (2+ AZs)
public_subnet_ids = ["subnet-public1", "subnet-public2"]     # Public subnets for ALB (2+ AZs)
```

**Requirements:**
- **Private subnets** must have NAT Gateway configured for outbound internet access
- **Public subnets** must have Internet Gateway configured
- Subnets must span **at least 2 availability zones**
- Sufficient IP addresses available (plan for future scaling)

### Security

#### HTTPS Configuration

**Production (Recommended):**
```hcl
# terraform.tfvars
alb_certificate_arn = "arn:aws:acm:us-east-1:123456:certificate/abc-123"
```
- HTTPS on port 443
- HTTP automatically redirects to HTTPS (301 redirect)
- TLS 1.3 policy enforced at the load balancer

**Development/Testing:**
```hcl
# terraform.tfvars
# (Leave alb_certificate_arn commented out or omit it)
```
- HTTP only on port 80
- No encryption (⚠️ not recommended for production use)

#### Access Control

**Restrict ALB to corporate network:**
```hcl
# terraform.tfvars
alb_ingress_cidr_blocks = ["10.0.0.0/8", "172.16.0.0/12"]  # Your corporate CIDRs
```

**Internal ALB (VPN/Direct Connect access only):**
```hcl
# terraform.tfvars
alb_internal = true  # Not accessible from public internet
```

#### Admin Password

The admin password is managed by Terraform and automatically configured during deployment.

**Option A: Let Terraform generate a random password (Default)**
```hcl
# No configuration needed - a secure random password is auto-generated
```

**Option B: Provide your own password**
```hcl
# terraform.tfvars
nexus_admin_password = "YourSecurePassword123!"
```

**Retrieve password after deployment:**
```bash
terraform output -raw nexus_admin_password
```

**Security note:** The password is set via the `NEXUS_SECURITY_INITIAL_PASSWORD` environment variable, which means:
- No forced password change on first login (automation-friendly)
- No `admin.password` file created on disk
- Password is available via Terraform outputs
- Works consistently across clustered deployments

### Storage Options

#### Blob Storage

**S3 (Recommended for Production and HA deployments):**
```hcl
# terraform.tfvars
blobstore_type = "s3"
```

**Benefits:**
- Unlimited scalability
- High durability (99.999999999%)
- Automatic encryption at rest (AES-256)
- Versioning enabled
- Required for clustered deployments (RA-3+)

**EBS Local File (For dev/test or specific workloads):**
```hcl
# terraform.tfvars
blobstore_type         = "file"
nexus_blob_volume_size = 500  # GB
nexus_blob_volume_type = "gp3"
```

**Benefits:**
- Lower latency for some workloads
- Simpler setup
- No S3 API calls

**Limitations:**
- Size limited by EBS volume limits (16 TiB max)
- Cannot be used with clustered deployments

#### Database

**PostgreSQL (RA-2 and above):**
```hcl
# terraform.tfvars
database_type = "postgres"
db_password   = "YourDatabasePassword"  # Minimum 16 characters required
```

**Features:**
- RDS Multi-AZ for high availability (RA-3+)
- Automated backups
- Point-in-time recovery
- Required for clustered deployments

**H2 Embedded (RA-1 only):**
```hcl
# terraform.tfvars
database_type = "h2"
```

**Limitations:**
- Not suitable for production environments
- Cannot be used with clustering
- No external backup capability

---

## DNS Setup (Custom Domain)

If you deployed with an ACM certificate, configure DNS to use your custom domain:

### Step 1: Get ALB DNS Name

```bash
terraform output alb_dns_name
```

Example output: `nxrm-20260324.us-east-1.elb.amazonaws.com`

### Step 2: Create DNS Record

**Option A: CNAME Record (Most DNS Providers)**

| Type  | Name                | Value                                     | TTL |
|-------|---------------------|-------------------------------------------|-----|
| CNAME | nexus.yourdom.com   | nxrm-20260324.us-east-1.elb.amazonaws.com | 300 |

**Option B: Route 53 Alias (AWS Route 53 Users)**

If you use AWS Route 53, create an A record with an alias to the ALB for better performance:

1. Open Route 53 in AWS Console
2. Select your hosted zone
3. Create record:
   - **Record name:** nexus.yourdom.com
   - **Record type:** A
   - **Alias:** Yes
   - **Route traffic to:** Alias to Application Load Balancer
   - **Region:** (select your deployment region)
   - **Load balancer:** (select your ALB from the list)
   - **Evaluate target health:** Yes

### Step 3: Wait for DNS Propagation

DNS propagation typically takes 1-5 minutes. Test:

```bash
nslookup nexus.yourdom.com
```

### Step 4: Access via Custom Domain

```
https://nexus.yourdom.com
```

The ACM certificate will automatically secure the connection.

---

## Accessing Nexus Repository

### Web Interface

1. Get the URL:
   ```bash
   terraform output nxrm_url
   ```

2. Get the admin password:
   ```bash
   terraform output -raw nexus_admin_password
   ```

3. Open URL in browser and login:
   - **Username:** `admin`
   - **Password:** (from previous command)

### SSH Access to EC2 Instances (Troubleshooting)

SSH keys are auto-generated. Connect via AWS Systems Manager (SSM):

```bash
# Get instance ID
INSTANCE_ID=$(terraform output -json instance_ids | jq -r '.[0]')

# Connect via SSM Session Manager (no SSH key needed, works through private subnet)
aws ssm start-session --target $INSTANCE_ID --region us-east-1
```

**Useful commands once connected:**
```bash
# Check Nexus Repository service status
sudo systemctl status nexus

# View Nexus Repository logs
sudo tail -f /opt/sonatype/sonatype-work/nexus3/log/nexus.log

# Check if Nexus Repository is responding locally
curl -I localhost:8081
```

**For clustered deployments (RA-3+):** Connect to each node using their respective instance IDs:
```bash
# Get all instance IDs
terraform output -json instance_ids

# Connect to second node
INSTANCE_ID=$(terraform output -json instance_ids | jq -r '.[1]')
aws ssm start-session --target $INSTANCE_ID --region us-east-1
```

---

## Troubleshooting

### Issue: "Cannot reach Nexus Repository at the ALB URL"

**Possible causes:**

1. **Nexus Repository is still starting up**
   Initial startup takes 2-5 minutes. For clustered deployments (RA-3+), allow 5-10 minutes for cluster formation.

   **Solution:** Wait a few minutes and try again. Check startup progress:
   ```bash
   # Connect to instance
   INSTANCE_ID=$(terraform output -json instance_ids | jq -r '.[0]')
   aws ssm start-session --target $INSTANCE_ID --region us-east-1

   # Check service status
   sudo systemctl status nexus

   # Watch startup logs
   sudo tail -f /opt/sonatype/sonatype-work/nexus3/log/nexus.log
   ```

2. **Target health checks failing**
   Check ALB target group health:
   ```bash
   # Get target group ARN
   TG_ARN=$(aws elbv2 describe-target-groups \
     --names $(terraform output -json | jq -r '.alb_dns_name.value' | cut -d'-' -f1-2) \
     --query 'TargetGroups[0].TargetGroupArn' --output text)

   # Check target health
   aws elbv2 describe-target-health --target-group-arn $TG_ARN
   ```

   **If unhealthy:** SSH into instance (see above) and check `sudo systemctl status nexus` and logs.

3. **Certificate mismatch (HTTPS)**
   If using HTTPS, ensure your ACM certificate covers the ALB DNS name or your custom domain.

   **Solution:** Use HTTP URL temporarily for testing, or verify certificate configuration matches your domain.

### Issue: "403 Forbidden" or "Invalid credentials"

**Cause:** Wrong admin password or password contains characters that were copied incorrectly.

**Solution:**
```bash
# Retrieve the correct password (copies to clipboard on macOS)
terraform output -raw nexus_admin_password | pbcopy

# Or display it (careful if screen sharing)
terraform output -raw nexus_admin_password

# Copy it exactly - no extra spaces, newlines, or special characters from terminal
```

### Issue: `terraform destroy` fails with "S3 bucket not empty"

**Cause:** S3 blob bucket contains artifacts and Terraform cannot delete non-empty buckets by default.

**Solution:**
```bash
# Get bucket name
BUCKET=$(terraform output -raw blobstore_bucket)

# Empty the bucket (removes all objects)
aws s3 rm s3://$BUCKET --recursive

# Remove all versions (versioning is enabled by default)
aws s3api delete-objects \
  --bucket $BUCKET \
  --delete "$(aws s3api list-object-versions \
    --bucket $BUCKET \
    --query '{Objects: Versions[].{Key: Key, VersionId: VersionId}}' \
    --max-items 1000)"

# Retry destroy
terraform destroy
```

**For development/testing environments:** Set `blobstore_force_destroy = true` in terraform.tfvars to automatically empty buckets on destroy (⚠️ not recommended for production).

### Issue: Database connection errors in logs

**Symptoms:** Nexus Repository logs show connection failures to PostgreSQL database.

**Check:**
```bash
# Connect to instance
INSTANCE_ID=$(terraform output -json instance_ids | jq -r '.[0]')
aws ssm start-session --target $INSTANCE_ID --region us-east-1

# Check database configuration
sudo cat /mnt/nexus-data/etc/fabric/nexus-store.properties

# Test database connectivity
PGPASSWORD=$(sudo grep password /mnt/nexus-data/etc/fabric/nexus-store.properties | cut -d= -f2) \
psql -h $(terraform output -raw database_endpoint | cut -d: -f1) -U nxrm -d nxrm -c "SELECT 1;"
```

**Solution:** Ensure `db_password` in terraform.tfvars matches what was deployed. If password was changed after initial deployment, you may need to redeploy or manually update the configuration.

### Issue: Out of disk space

**Check volume usage:**
```bash
# Connect to instance
INSTANCE_ID=$(terraform output -json instance_ids | jq -r '.[0]')
aws ssm start-session --target $INSTANCE_ID --region us-east-1

# Check disk usage
df -h

# Check specific Nexus Repository directories
du -sh /mnt/nexus-data
du -sh /mnt/nexus-blobs  # if using file blobstore
```

**Solution:** Increase volume sizes in terraform.tfvars:
```hcl
nexus_data_volume_size = 500   # Increase from 200 GB
nexus_blob_volume_size = 1000  # Increase from 200 GB (file blobstore only)
```

Then run `terraform apply`. Terraform will update the volumes without recreating instances.

### Issue: "License file required for clustered deployments"

**Symptoms:** Terraform validation fails with message about missing license file.

**Solution:** Clustered deployments (RA-3+) require a paid Sonatype Nexus Repository Pro license:
```bash
# Place your Pro license file
cp your-license.lic files_to_upload_to_nodes/

# Verify it's present
ls -lh files_to_upload_to_nodes/*.lic
```

---

## Cleanup

To destroy all resources and stop incurring AWS charges:

```bash
terraform destroy
```

**⚠️ WARNING:** This action permanently deletes:
- All EC2 instances and associated EBS volumes
- RDS database including all data
- S3 buckets and all stored artifacts (if `blobstore_force_destroy = true`)
- Load balancer and networking resources
- VPC and subnets (if created by Terraform)
- All IAM roles, security groups, and keys

**This action is irreversible.** Before destroying production environments:

1. **Export critical data:**
   ```bash
   # Database backup (if using PostgreSQL)
   # Connect to instance and export
   pg_dump -h $(terraform output -raw database_endpoint | cut -d: -f1) \
     -U nxrm -d nxrm > nxrm_backup.sql

   # Download important artifacts from blob store
   aws s3 sync s3://$(terraform output -raw blobstore_bucket) ./backup/
   ```

2. **Document configurations:**
   - Export Terraform state: `terraform state pull > terraform.tfstate.backup`
   - Document any custom Nexus Repository configurations
   - Save admin credentials

3. **Verify backups** before proceeding with destroy

**For S3 buckets:** If destroy fails due to non-empty S3 buckets, see troubleshooting section above.

---

## Additional Resources

- **[Sonatype Nexus Repository Documentation](https://help.sonatype.com/en/sonatype-nexus-repository.html)** - Official product documentation
- **[Reference Architecture Guide](https://help.sonatype.com/en/sonatype-nexus-repository-reference-architectures.html)** - Detailed RA specifications and sizing guidance
- **[Terraform AWS Provider](https://registry.terraform.io/providers/hashicorp/aws/latest/docs)** - AWS resource documentation
- **[AWS Well-Architected Framework](https://aws.amazon.com/architecture/well-architected/)** - Best practices for cloud architecture

### Documentation in This Folder

- `docs/architecture-overview.md` - Architecture diagrams and component descriptions
- `docs/prerequisites.md` - Detailed prerequisites and AWS account setup
- `docs/getting-started.md` - Extended getting started guide with examples
- `docs/operations/` - Backup, monitoring, and scaling guides
- `docs/reference-architectures/` - Per-RA detailed specifications
- `docs/security/` - Security hardening and compliance guidance

---

## License

Copyright (c) 2008-present Sonatype, Inc.

All rights reserved. Includes third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions

---

## Support and Responsibility

**This Terraform template is provided as-is to help you deploy Sonatype Nexus Repository infrastructure on AWS.** While this template simplifies the deployment process, please understand:

**You (the customer) are solely responsible for:**
- All AWS costs incurred by deployed resources
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
- AWS cost management or optimization services
- Custom modifications to this Terraform code

**For Sonatype Nexus Repository Pro customers:** While we do not provide custom Terraform development, our support team can offer guidance on Nexus Repository configuration, sizing, and best practices. For infrastructure-specific questions, please consult your internal DevOps or cloud teams, or engage an AWS partner for professional services.

**Questions about this template?** Open an issue in this repository or consult the documentation in the `docs/` folder.

**Questions about Sonatype Nexus Repository features?** Contact [Sonatype Support](https://support.sonatype.com) if you are a Pro customer.
