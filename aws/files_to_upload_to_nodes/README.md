# Sonatype Nexus Repository Manager Installer Files

**Before running `terraform apply`, place the following files in this directory:**

## Required Files

### 1. Nexus Repository Manager  Installer

```bash
nexus*.tar.gz
```

- Download from: [Sonatype Help Center](https://help.sonatype.com/en/download.html)
- Must be the **Unix/Linux (.tar.gz)** version
    - Make sure to download a version matching the EC2 nodes' system architecture (default for the tfvars files is arm64).
- Any filename starting with `nexus` and ending with `.tar.gz`
- Examples:
  - `nexus-3.90.2-unix.tar.gz`
  - `nexus-professional-3.90.2-unix.tar.gz`
  - `nexus-repository-manager-3.90.2.tar.gz`

### 2. License File (Optional - Required for RA-2+)

```bash
*.lic
```

- Required for: RA-2, RA-3, RA-4, RA-5 (Pro license needed)
- Optional for: RA-1 (can use Community Edition)
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
# nexus-3.90.2-unix.tar.gz
# your-license.lic
# README.md (this file)
# .gitkeep
```

## What Happens

During `terraform apply`, these files are:
- Uploaded to an S3 bucket (temporary staging)
- Copied to EC2 instances during provisioning
- Installed and configured automatically

The Terraform configuration validates these files exist before deployment to prevent errors.

## Important Notes

- ⚠️ **Keep your license file confidential** - it's tied to your organization
- ✅ Only one installer tar.gz file should be present
- ✅ For RA-2+, one license .lic file is required

## Troubleshooting

**Error: "No NXRM installer tarball found"**
- Check that the installer file is present and starts with `nexus` and ends with `.tar.gz`
- Ensure only ONE installer tar.gz file exists in this directory
- Remove any backup or old versions

**Error: License file issues**
- For RA-2+: Ensure a valid Pro license file ending with `.lic` exists
- For RA-1: License file is optional
- Ensure only ONE .lic file exists in this directory
- File can have any name as long as it ends with `.lic`
