#!/bin/bash
# Copyright (c) 2008-present Sonatype, Inc. Installs the Nexus tarball (it bundles its JDK) pulled with the VM identity.
set -euo pipefail

SONATYPE_DIR="/opt/sonatype"
NEXUS_HOME="$${SONATYPE_DIR}/nexus"
SONATYPE_WORK="$${SONATYPE_DIR}/sonatype-work"
NEXUS_DATA="$${SONATYPE_WORK}/nexus3"
DOWNLOAD_DIR=$(mktemp -d /var/tmp/nxrm-install.XXXXXX)
trap 'rm -rf "$${DOWNLOAD_DIR}"' EXIT

dnf -y install jq tar curl

# Shared helpers: blob_get and kv_get
# shellcheck source=/dev/null
. /opt/nxrm-bootstrap/lib.sh

TARBALL="$${DOWNLOAD_DIR}/nexus.tar.gz"
# Large download: 30 minute transfer limit instead of 20 s.
blob_get "${tarball_blob}" "$${TARBALL}" 1800
tar -tzf "$${TARBALL}" > /dev/null || { echo "ERROR: ${tarball_blob} is not a valid tar.gz archive" >&2; exit 1; }

# nexus role account, uid/gid 200
getent group nexus > /dev/null || groupadd -r -g 200 nexus
id -u nexus > /dev/null 2>&1 || useradd -r -u 200 -g nexus -M -d "$${SONATYPE_WORK}" -s /sbin/nologin -c "nexus role account" nexus
cat > /etc/security/limits.d/90-nexus.conf <<'LIMITS'
nexus - nofile 65536
LIMITS

# Program files are replaced; sonatype-work (data) is never touched.
STAGE=$(mktemp -d "$${SONATYPE_DIR}/.nexus-extract.XXXXXX")
tar --no-same-owner -xzf "$${TARBALL}" -C "$${STAGE}"
LAUNCHER=$(find "$${STAGE}" -maxdepth 4 -type f -path '*/bin/nexus' | head -1)
if [ -z "$${LAUNCHER}" ]; then
    echo "ERROR: bin/nexus not found in ${tarball_blob}" >&2
    exit 1
fi
rm -rf "$${NEXUS_HOME}"
mv "$(dirname "$(dirname "$${LAUNCHER}")")" "$${NEXUS_HOME}"
rm -rf "$${STAGE}"
# bin/nexus starts the JDK that ships in jdk/; there is no system Java.
if ! compgen -G "$${NEXUS_HOME}/jdk/*_linux_$(uname -m)/*/bin/java" > /dev/null; then
    echo "ERROR: ${tarball_blob} has no bundled JDK for $(uname -m); use the Nexus Linux archive for this CPU" >&2
    exit 1
fi

chmod -R +x "$${NEXUS_HOME}/bin/"
chown -R root:root "$${NEXUS_HOME}"
echo 'run_as_user="nexus"' > "$${NEXUS_HOME}/bin/nexus.rc"
# The bootstrap runs with umask 077; the service user must still read the launcher config.
chmod 644 "$${NEXUS_HOME}/bin/nexus.rc"

# Keep only the newest launcher jar
shopt -s nullglob
JARS=("$${NEXUS_HOME}"/bin/sonatype-nexus-repository-*.jar)
if [ "$${#JARS[@]}" -gt 1 ]; then
    LATEST_JAR=$(ls -t "$${JARS[@]}" | head -1)
    for jar in "$${JARS[@]}"; do
        [ "$${jar}" != "$${LATEST_JAR}" ] && rm -f "$${jar}"
    done
fi
shopt -u nullglob

mkdir -p "$${NEXUS_DATA}/etc"
%{ if license_blob != "" ~}
blob_get "${license_blob}" "$${DOWNLOAD_DIR}/license.lic"
install -m 600 -o nexus -g nexus "$${DOWNLOAD_DIR}/license.lic" "$${NEXUS_DATA}/etc/license.lic"
echo "License installed"
%{ else ~}
rm -f "$${NEXUS_DATA}/etc/license.lic"
echo "No license provided"
%{ endif ~}
chown -R nexus:nexus "$${SONATYPE_WORK}"
echo "Nexus installed in $${NEXUS_HOME}"
