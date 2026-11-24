# Sonatype Nexus Repository Installer Files

**Before running `terraform apply`, place the following files in this directory:**

## Required Files

### 1. Nexus Repository Installer

```bash
nexus*.tar.gz
```

- Download from: [Sonatype Help Center](https://help.sonatype.com/en/download.html)
- Must be the **Linux x86_64 (.tar.gz)** version
    - The Azure VMs are x86_64. Download the x86_64 Linux version.
- Any filename starting with `nexus` and ending with `.tar.gz`
- Examples:
  - `nexus-3.98.0-07-linux-x86_64.tar.gz`
  - `nexus-repository-manager-3.90.2.tar.gz`

### 2. License File (Optional - Required for RA-3+)

```bash
*.lic
```

- Required for: RA-3, RA-4, RA-5 (clustering needs a Pro license)
- Optional for: RA-1 (can use Community Edition) and RA-2
- Obtain from: Sonatype sales or support
- Any filename ending with `.lic`
- Examples:
  - `license.lic`
  - `sonatype-license.lic`
  - `nxrm.lic`

## Usage

```bash
# Place your files here
cp ~/Downloads/nexus*.tar.gz files_to_upload_to_nodes/
cp ~/Downloads/*.lic files_to_upload_to_nodes/

# Verify files are in place
ls -lh files_to_upload_to_nodes/

# Expected output (filenames may vary):
# nexus-3.98.0-07-linux-x86_64.tar.gz
# your-license.lic
# README.md (this file)
```

## What Happens

During `terraform apply`, these files are:
- Uploaded to a private container in an Azure Storage account
- Downloaded by the VMs at first boot, using a managed identity
- Installed and configured automatically

The Terraform configuration validates these files before deployment to prevent errors.

## Important Notes

- ⚠️ **Keep your license file confidential** - it's tied to your organization
- ✅ Only one installer tar.gz file should be present
- ✅ For RA-3+, one license .lic file is required

## Troubleshooting

**Error: "Place exactly one nexus*.tar.gz file in files_to_upload_to_nodes/ (e.g., nexus-3.98.0-07-linux-x86_64.tar.gz)"**
- Check that the installer file is present and starts with `nexus` and ends with `.tar.gz`
- Ensure only ONE installer tar.gz file exists in this directory
- Remove any backup or old versions

**Error: "Place at most one *.lic file in files_to_upload_to_nodes/ (optional for a single node, required for clusters)"**
- Ensure only ONE .lic file exists in this directory

**Error: "A license file (*.lic) is required in files_to_upload_to_nodes/ for clustered deployments. Clustering requires NXRM Pro edition."**
- For RA-3+: place a valid Pro license file ending with `.lic` in this directory
- For RA-1 and RA-2: a license file is optional
