#!/bin/bash
# Copyright (c) 2008-present Sonatype, Inc. Installs Java 21 and the Nexus tarball pulled with the VM identity.
set -euo pipefail

SONATYPE_DIR="/opt/sonatype"
NEXUS_HOME="$${SONATYPE_DIR}/nexus"
SONATYPE_WORK="$${SONATYPE_DIR}/sonatype-work"
NEXUS_DATA="$${SONATYPE_WORK}/nexus3"
DOWNLOAD_DIR=$(mktemp -d /var/tmp/nxrm-install.XXXXXX)
trap 'rm -rf "$${DOWNLOAD_DIR}"' EXIT

dnf -y install jq tar curl
if ! dnf -y install java-21-openjdk-headless; then
    echo "ERROR: package java-21-openjdk-headless is not available; enable the Oracle Linux AppStream repository" >&2
    exit 1
fi
java -version 2>&1 | head -1

# A token minted before the role assignment propagates has no grant, so mint one per attempt.
blob_get() {
    local blob="$1" dest="$2" max_time="$${3:-20}" token http attempt
    http=000
    for attempt in $(seq 1 10); do
        token=$(curl -sS --connect-timeout 10 --max-time 20 -H Metadata:true "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fstorage.azure.com%2F&client_id=${identity_client_id}" | jq -r '.access_token // empty' || true)
        if [ -z "$${token}" ]; then
            echo "attempt $${attempt}: no managed identity token yet"
            sleep 15
            continue
        fi
        http=$(printf 'header = "Authorization: Bearer %s"\n' "$${token}" | curl -sS --connect-timeout 10 --max-time "$${max_time}" -K - -w '%%{http_code}' -o "$${dest}" -H "x-ms-version: 2021-08-06" "https://${artifacts_account}.blob.core.windows.net/${artifacts_container}/$${blob}" || true)
        [ "$${http}" = "200" ] && return 0
        echo "attempt $${attempt}: HTTP $${http} for $${blob} (role assignment may still be propagating)"
        rm -f "$${dest}"
        sleep 15
    done
    echo "ERROR: download of $${blob} failed, last HTTP $${http}" >&2
    return 1
}

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
