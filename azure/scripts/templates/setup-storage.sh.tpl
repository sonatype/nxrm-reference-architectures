#!/bin/bash
# Copyright (c) 2008-present Sonatype, Inc. Mounts the LUN 0 data disk at /opt/sonatype; never reformats.
set -euo pipefail

DISK_LINK="/dev/disk/azure/scsi1/lun0"
MOUNT_POINT="/opt/sonatype"

# The disk attachment is a separate resource applied after the VM, so LUN 0 can appear minutes later.
for i in $(seq 1 180); do
    [ -e "$${DISK_LINK}" ] && break
    [ $((i % 12)) -eq 0 ] && echo "Still waiting for $${DISK_LINK} ($((i * 5)) s of 900 s)..."
    sleep 5
done
if [ ! -e "$${DISK_LINK}" ]; then
    echo "ERROR: data disk $${DISK_LINK} not attached after 900 s; check the data disk attachment on this VM" >&2
    exit 1
fi
DISK=$(readlink -f "$${DISK_LINK}")
echo "Data disk: $${DISK_LINK} -> $${DISK}"

FS_TYPE=$(blkid -o value -s TYPE "$${DISK}" || true)
PT_TYPE=$(blkid -o value -s PTTYPE "$${DISK}" || true)
if [ -z "$${FS_TYPE}" ] && [ -n "$${PT_TYPE}" ]; then
    echo "ERROR: $${DISK} has a partition table but no filesystem; refusing to format it" >&2
    exit 1
fi
if [ -z "$${FS_TYPE}" ]; then
    echo "No filesystem on $${DISK}: creating ext4"
    mkfs.ext4 -L nxrm-data "$${DISK}"
else
    echo "Keeping existing $${FS_TYPE} filesystem on $${DISK}"
fi

DISK_UUID=$(blkid -o value -s UUID "$${DISK}")
if [ -z "$${DISK_UUID}" ]; then
    echo "ERROR: no UUID found for $${DISK}" >&2
    exit 1
fi

mkdir -p "$${MOUNT_POINT}"
if ! grep -q "^UUID=$${DISK_UUID} " /etc/fstab; then
    echo "UUID=$${DISK_UUID} $${MOUNT_POINT} ext4 defaults,nofail,x-systemd.device-timeout=120s 0 2" >> /etc/fstab
fi
systemctl daemon-reload
mountpoint -q "$${MOUNT_POINT}" || mount "$${MOUNT_POINT}"
mountpoint -q "$${MOUNT_POINT}" || { echo "ERROR: $${MOUNT_POINT} is not mounted" >&2; exit 1; }
echo "Storage ready: $(df -h "$${MOUNT_POINT}" | tail -1)"
