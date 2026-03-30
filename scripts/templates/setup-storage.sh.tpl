#!/bin/bash
# Formats and mounts EBS volumes for NXRM.
set -euo pipefail

setup_volume() {
    local device="$1" mount_point="$2" label="$3"
    echo "Setting up $${label}: $${device} -> $${mount_point}"

    for i in $(seq 1 30); do
        [ -b "$${device}" ] && break
        echo "Waiting for $${device} ($${i}/30)..."
        sleep 5
    done

    if [ ! -b "$${device}" ]; then
        echo "ERROR: $${device} not found after 150s"
        exit 1
    fi

    if ! mountpoint -q "$${mount_point}"; then
        mkfs.ext4 -E nodiscard "$${device}"
        mkdir -p "$${mount_point}"
        mount -o defaults,nofail "$${device}" "$${mount_point}"
        echo "$${device} $${mount_point} ext4 defaults,nofail 0 2" >> /etc/fstab
    fi
}

# Data volume (always provisioned)
setup_volume "/dev/xvdh" "/mnt/nexus-data" "data"

# Blob storage volume (file blobstore only)
%{ if blobstore_type == "file" ~}
setup_volume "/dev/xvdi" "/mnt/nexus-blobs" "blobs"
%{ endif ~}

mkdir -p /opt/sonatype
echo "Storage setup complete"
