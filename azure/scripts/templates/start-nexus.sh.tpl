#!/bin/bash
# Copyright (c) 2008-present Sonatype, Inc. Starts Nexus through systemd and waits for the status endpoint.
set -euo pipefail

STATUS_URL="http://127.0.0.1:8081/service/rest/v1/status"

%{ if database_type == "postgres" ~}
db_up=false
for i in $(seq 1 60); do
    if timeout 5 bash -c "exec 3<>/dev/tcp/${db_host}/${db_port}" 2> /dev/null; then
        db_up=true
        break
    fi
    echo "Waiting for PostgreSQL ${db_host}:${db_port} ($${i}/60)..."
    sleep 10
done
if [ "$${db_up}" != "true" ]; then
    echo "ERROR: PostgreSQL ${db_host}:${db_port} not reachable after 10 minutes; check the server and the db subnet" >&2
    exit 1
fi
%{ endif ~}

fail_with_diagnostics() {
    echo "ERROR: $1" >&2
    systemctl status nexus --no-pager >&2 || true
    journalctl -u nexus -n 50 --no-pager >&2 || true
    exit 1
}

# Last resort only: permissive SELinux when systemd cannot execute Nexus (203/EXEC), then one retry.
selinux_fallback() {
    [ "$(getenforce 2> /dev/null)" = "Enforcing" ] || return 1
    systemctl show nexus -p ExecMainStatus --value | grep -qx 203 ||
        journalctl -u nexus -n 50 --no-pager | grep -q '203/EXEC' || return 1
    echo "WARNING: nexus failed with 203/EXEC under SELinux enforcing; switching SELinux to permissive"
    setenforce 0
    sed -i 's/^SELINUX=enforcing/SELINUX=permissive/' /etc/selinux/config
    systemctl reset-failed nexus
    systemctl start nexus
}

systemctl daemon-reload
systemctl enable nexus
systemctl start nexus || selinux_fallback || fail_with_diagnostics "nexus.service did not start"

for i in $(seq 1 90); do
    if curl -sf --connect-timeout 10 --max-time 20 -o /dev/null "$${STATUS_URL}"; then
        echo "Nexus is up after ~$((i * 10)) s"
        exit 0
    fi
    systemctl is-failed --quiet nexus && fail_with_diagnostics "nexus.service failed while starting"
    sleep 10
done
fail_with_diagnostics "$${STATUS_URL} not available after 15 minutes"
