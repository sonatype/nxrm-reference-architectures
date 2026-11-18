#!/bin/bash
set -euo pipefail

mkdir -p /tmp/nxrm-install

# Download installer and optional license from S3
aws s3 sync s3://${artifact_bucket}/nxrm-assets/ /tmp/nxrm-install/ \
  --region ${aws_region} \
  --exclude "*" \
  --include "nexus*.tar.gz" \
  --include "*.lic"

if ! ls /tmp/nxrm-install/nexus*.tar.gz 1>/dev/null 2>&1; then
  echo "ERROR: NXRM installer not found in S3 bucket"
  exit 1
fi

# Embed and execute provisioning scripts
cat > /tmp/setup-storage.sh <<'SETUP_EOF'
${setup_storage_script}
SETUP_EOF

cat > /tmp/configure-nexus.sh <<'CONFIGURE_EOF'
${configure_nexus_script}
CONFIGURE_EOF

chmod +x /tmp/setup-storage.sh /tmp/configure-nexus.sh
/tmp/setup-storage.sh
/tmp/configure-nexus.sh

# Clean up (scripts contain DB credentials)
rm -f /tmp/setup-storage.sh /tmp/configure-nexus.sh
