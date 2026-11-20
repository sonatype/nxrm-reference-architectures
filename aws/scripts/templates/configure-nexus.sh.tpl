#!/bin/bash
# Configures and starts Nexus Repository Manager.
set -euo pipefail

SONATYPE_DIR="/opt/sonatype"
NEXUS_HOME="$${SONATYPE_DIR}/nexus"
NEXUS_DATA="/mnt/nexus-data"
SONATYPE_WORK="$${SONATYPE_DIR}/sonatype-work"

echo "Configuring NXRM (ra=${ra_size}, clustered=${clustered}, db=${db_engine})"

# Create nexus user
if ! id -u nexus &>/dev/null; then
    useradd -r -u 200 -m -c "nexus role account" -d "$${NEXUS_DATA}" -s /bin/false nexus
fi

mkdir -p "$${NEXUS_DATA}/etc" "$${SONATYPE_WORK}"

grep -q "nexus hard nofile" /etc/security/limits.conf || {
    echo "nexus hard nofile 65536" >> /etc/security/limits.conf
    echo "nexus soft nofile 65536" >> /etc/security/limits.conf
}

# Install NXRM from tarball
NEXUS_TAR_GZ=$(find /tmp/nxrm-install /tmp -maxdepth 1 -name "nexus*.tar.gz" 2>/dev/null | head -1)
if [ -z "$${NEXUS_TAR_GZ}" ]; then
    echo "ERROR: No NXRM installer tarball found"
    exit 1
fi

tar --no-same-owner -xzf "$${NEXUS_TAR_GZ}" -C "$${SONATYPE_DIR}"

NEXUS_EXTRACTED=$(ls -dt "$${SONATYPE_DIR}"/nexus-* 2>/dev/null | head -1)
if [ -n "$${NEXUS_EXTRACTED}" ] && [ "$${NEXUS_EXTRACTED}" != "$${NEXUS_HOME}" ]; then
    rm -rf "$${NEXUS_HOME}"
    mv "$${NEXUS_EXTRACTED}" "$${NEXUS_HOME}"
fi

# Symlink sonatype-work/nexus3 -> data volume (must be after tarball extraction)
rm -rf "$${SONATYPE_WORK}/nexus3"
ln -sT "$${NEXUS_DATA}" "$${SONATYPE_WORK}/nexus3"

chmod -R +x "$${NEXUS_HOME}/bin/"*
chown -R root:root "$${NEXUS_HOME}"
echo 'run_as_user="nexus"' > "$${NEXUS_HOME}/bin/nexus.rc"

# Clean up duplicate jars (keep latest)
cd "$${NEXUS_HOME}/bin"
LATEST_JAR=$(ls -t sonatype-nexus-repository-*.jar 2>/dev/null | head -1)
if [ -n "$${LATEST_JAR}" ]; then
    for jar in sonatype-nexus-repository-*.jar; do
        [ "$${jar}" != "$${LATEST_JAR}" ] && rm -f "$${jar}"
    done
fi

# nexus.properties
cp "$${NEXUS_HOME}/etc/nexus-default.properties" "$${NEXUS_DATA}/etc/nexus.properties"
cat >> "$${NEXUS_DATA}/etc/nexus.properties" <<NXPROPS
karaf.data=$${SONATYPE_WORK}/nexus3
nexus.skipDefaultRepositories=true
nexus.blobstore.provisionDefaults=false
NXPROPS

# License file (optional)
LICENSE_FILE=$(find /tmp/nxrm-install /tmp -maxdepth 1 -name "*.lic" 2>/dev/null | head -1)
LICENSE_NAME=""
if [ -n "$${LICENSE_FILE}" ]; then
    LICENSE_NAME=$(basename "$${LICENSE_FILE}")
    cp "$${LICENSE_FILE}" "$${NEXUS_DATA}/etc/$${LICENSE_NAME}"
    echo "nexus.licenseFile=$${NEXUS_DATA}/etc/$${LICENSE_NAME}" >> "$${NEXUS_DATA}/etc/nexus.properties"
    echo "License installed: $${LICENSE_NAME}"
else
    echo "No license found, starting in Community Edition mode"
fi

# Database
%{ if db_engine == "postgres" ~}
echo "nexus.datastore.enabled=true" >> "$${NEXUS_DATA}/etc/nexus.properties"
mkdir -p "$${NEXUS_DATA}/etc/fabric"
chmod 700 "$${NEXUS_DATA}/etc/fabric"
cat > "$${NEXUS_DATA}/etc/fabric/nexus-store.properties" <<DBPROPS
type=jdbc
jdbcUrl=jdbc:postgresql://${db_host}:${db_port}/${db_name}
username=${db_username}
password=${db_password}
maximumPoolSize=${db_connection_pool}
DBPROPS
chmod 600 "$${NEXUS_DATA}/etc/fabric/nexus-store.properties"
%{ endif ~}

# Clustering
%{ if clustered ~}
echo "nexus.datastore.clustered.enabled=true" >> "$${NEXUS_DATA}/etc/nexus.properties"
%{ endif ~}

# Blob store
%{ if blobstore_type == "file" ~}
BLOB_MOUNT="/mnt/nexus-blobs"
if [ ! -d "$${BLOB_MOUNT}" ]; then
    echo "ERROR: Blob mount $${BLOB_MOUNT} not found"
    exit 1
fi
if [ ! -L "$${NEXUS_DATA}/blobs" ]; then
    rm -rf "$${NEXUS_DATA}/blobs"
    ln -sT "$${BLOB_MOUNT}" "$${NEXUS_DATA}/blobs"
fi
chown -R nexus:nexus "$${BLOB_MOUNT}"
%{ endif ~}
%{ if s3_bucket != "" ~}
echo "nexus.blobstore.s3.ownership.check.disabled=true" >> "$${NEXUS_DATA}/etc/nexus.properties"
cat > "$${NEXUS_DATA}/etc/s3-blobstore.json" <<S3CFG
{
  "type": "s3",
  "name": "default",
  "attributes": {
    "s3": {
      "bucket": "${s3_bucket}",
      "region": "${s3_region}"
    }
  }
}
S3CFG
%{ endif ~}

# JVM settings
VMOPTIONS_FILE="$${NEXUS_HOME}/bin/nexus.vmoptions"
if [ -f "$${VMOPTIONS_FILE}" ]; then
    sed -i "s/-Xms[0-9]*[mg]/-Xms${java_heap_min}/" "$${VMOPTIONS_FILE}"
    sed -i "s/-Xmx[0-9]*[mg]/-Xmx${java_heap_max}/" "$${VMOPTIONS_FILE}"
    if grep -q "MaxDirectMemorySize" "$${VMOPTIONS_FILE}"; then
        sed -i "s/-XX:MaxDirectMemorySize=[0-9]*[mg]/-XX:MaxDirectMemorySize=${java_direct_memory}/" "$${VMOPTIONS_FILE}"
    else
        echo "-XX:MaxDirectMemorySize=${java_direct_memory}" >> "$${VMOPTIONS_FILE}"
    fi
fi

# Permissions
chown -R nexus:nexus "$${NEXUS_DATA}" "$${SONATYPE_WORK}"
%{ if blobstore_type == "file" ~}
chown -R nexus:nexus /mnt/nexus-blobs
%{ endif ~}

# Install Java 21
if ! java -version 2>&1 | grep -q "21"; then
    yum install -y java-21-amazon-corretto
%{ if instance_arch == "arm64" ~}
    alternatives --set java /usr/lib/jvm/java-21-amazon-corretto.aarch64/bin/java
%{ else ~}
    alternatives --set java /usr/lib/jvm/java-21-amazon-corretto.x86_64/bin/java
%{ endif ~}
fi

# Systemd service
cat > /etc/systemd/system/nexus.service <<SVCFILE
[Unit]
Description=Sonatype Nexus Repository Manager
After=network.target

[Service]
Type=forking
LimitNOFILE=65536
Environment="NEXUS_SECURITY_INITIAL_PASSWORD=${nexus_admin_password}"
ExecStart=$${NEXUS_HOME}/bin/nexus start
ExecStop=$${NEXUS_HOME}/bin/nexus stop
User=nexus
Restart=on-abort
TimeoutSec=600

[Install]
WantedBy=multi-user.target
SVCFILE

systemctl daemon-reload
systemctl enable nexus

# Start NXRM
%{ if db_engine == "postgres" ~}
echo "Waiting 30s for database readiness..."
sleep 30
%{ endif ~}
systemctl start nexus
echo "NXRM provisioning complete"
