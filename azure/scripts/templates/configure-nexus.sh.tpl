#!/bin/bash
# Copyright (c) 2008-present Sonatype, Inc. Writes Nexus configuration; secrets are read from the secrets blob at runtime.
set -euo pipefail
set +x

SONATYPE_DIR="/opt/sonatype"
NEXUS_HOME="$${SONATYPE_DIR}/nexus"
SONATYPE_WORK="$${SONATYPE_DIR}/sonatype-work"
NEXUS_DATA="$${SONATYPE_WORK}/nexus3"
PROPS="$${NEXUS_DATA}/etc/nexus.properties"
umask 077

blob_get() {
    local blob="$1" dest="$2" token http attempt
    http=000
    for attempt in $(seq 1 10); do
        token=$(curl -sS --connect-timeout 10 --max-time 20 -H Metadata:true "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fstorage.azure.com%2F&client_id=${identity_client_id}" | jq -r '.access_token // empty' || true)
        if [ -z "$${token}" ]; then
            echo "attempt $${attempt}: no managed identity token yet"
            sleep 15
            continue
        fi
        http=$(printf 'header = "Authorization: Bearer %s"\n' "$${token}" | curl -sS --connect-timeout 10 --max-time 20 -K - -w '%%{http_code}' -o "$${dest}" -H "x-ms-version: 2021-08-06" "https://${artifacts_account}.blob.core.windows.net/${artifacts_container}/$${blob}" || true)
        [ "$${http}" = "200" ] && return 0
        echo "attempt $${attempt}: HTTP $${http} for $${blob}"
        rm -f "$${dest}"
        sleep 15
    done
    echo "ERROR: download of $${blob} failed, last HTTP $${http}" >&2
    return 1
}

# EnvironmentFile double quotes take the same escapes as bash: \\ \" \$ \`; Java properties: \\ and spaces.
env_quote() { local v="$1"; v="$${v//\\/\\\\}"; v="$${v//\"/\\\"}"; v="$${v//\$/\\\$}"; v="$${v//\`/\\\`}"; printf '"%s"' "$${v}"; }
prop_escape() { local v="$1"; v="$${v//\\/\\\\}"; v="$${v// /\\ }"; printf '%s' "$${v}"; }
no_newline() { case "$2" in *$'\n'*) echo "ERROR: $1 must not contain a newline" >&2; exit 1 ;; esac; }
prop() { printf '%s=%s\n' "$1" "$2" >> "$${PROPS}"; }

SECRETS_FILE=$(mktemp /run/nxrm-secrets.XXXXXX)
trap 'rm -f "$${SECRETS_FILE}"' EXIT
blob_get "${secrets_blob}" "$${SECRETS_FILE}"
ADMIN_PASSWORD=$(jq -r '.nexus_admin_password' "$${SECRETS_FILE}")
if [ -z "$${ADMIN_PASSWORD}" ] || [ "$${ADMIN_PASSWORD}" = "null" ]; then
    echo "ERROR: nexus_admin_password missing from the secrets blob" >&2
    exit 1
fi
no_newline nexus_admin_password "$${ADMIN_PASSWORD}"

# nexus.properties overlay, rebuilt on every run
mkdir -p "$${NEXUS_DATA}/etc"
: > "$${PROPS}"
prop application-port 8081
%{ if tls_mode == "nginx" ~}
prop application-host 127.0.0.1
%{ else ~}
prop application-host 0.0.0.0
%{ endif ~}
prop karaf.data "$${NEXUS_DATA}"
prop nexus.skipDefaultRepositories true
%{ if blobstore_type == "azure" ~}
# The Azure blob store is created later; the file default stays only for the file blob store.
prop nexus.blobstore.provisionDefaults false
%{ endif ~}
prop nexus.onboarding.enabled false
# VERIFY-ON-NODE: nexus.baseUrl as a startup property (the internal template sets it the same way).
prop nexus.baseUrl "${base_url}"
if [ -f "$${NEXUS_DATA}/etc/license.lic" ]; then
    prop nexus.licenseFile "$${NEXUS_DATA}/etc/license.lic"
fi

%{ if database_type == "postgres" ~}
DB_PASSWORD=$(jq -r '.db_password' "$${SECRETS_FILE}")
if [ -z "$${DB_PASSWORD}" ] || [ "$${DB_PASSWORD}" = "null" ]; then
    echo "ERROR: db_password missing from the secrets blob" >&2
    exit 1
fi
no_newline db_password "$${DB_PASSWORD}"
prop nexus.datastore.enabled true
mkdir -p "$${NEXUS_DATA}/etc/fabric"
chmod 700 "$${NEXUS_DATA}/etc/fabric"
STORE="$${NEXUS_DATA}/etc/fabric/nexus-store.properties"
{
    echo "type=jdbc"
    echo "jdbcUrl=jdbc:postgresql://${db_host}:${db_port}/${db_name}?sslmode=require"
    echo "username=${db_user}"
    printf 'password=%s\n' "$(prop_escape "$${DB_PASSWORD}")"
    echo "maximumPoolSize=${nxrm_connection_pool}"
} > "$${STORE}"
chmod 600 "$${STORE}"
unset DB_PASSWORD
echo "Datastore: PostgreSQL ${db_host}:${db_port}/${db_name}"
%{ else ~}
rm -f "$${NEXUS_DATA}/etc/fabric/nexus-store.properties"
echo "Datastore: embedded H2"
%{ endif ~}
%{ if clustered ~}
prop nexus.datastore.clustered.enabled true
%{ endif ~}
chown -R nexus:nexus "$${NEXUS_DATA}/etc"

# JVM sizing
VMOPTIONS="$${NEXUS_HOME}/bin/nexus.vmoptions"
if [ ! -f "$${VMOPTIONS}" ]; then
    echo "ERROR: $${VMOPTIONS} not found; cannot set the JVM heap" >&2
    exit 1
fi
sed -i -E '/^-Xms/d; /^-Xmx/d; /^-XX:MaxDirectMemorySize=/d' "$${VMOPTIONS}"
printf '%s\n' "-Xms${java_min_heap}" "-Xmx${java_max_heap}" "-XX:MaxDirectMemorySize=${java_max_direct_memory}" >> "$${VMOPTIONS}"
chmod 644 "$${VMOPTIONS}"

# Root-only environment file; the initial password is used on first start only.
{
    printf 'NEXUS_SECURITY_INITIAL_PASSWORD=%s\n' "$(env_quote "$${ADMIN_PASSWORD}")"
    printf 'AZURE_CLIENT_ID=%s\n' "${identity_client_id}"
} > /etc/nexus.env
chown root:root /etc/nexus.env
chmod 600 /etc/nexus.env
unset ADMIN_PASSWORD

cat > /etc/systemd/system/nexus.service <<UNIT
[Unit]
Description=Sonatype Nexus Repository
Wants=network-online.target
After=network-online.target
RequiresMountsFor=$${SONATYPE_DIR}

[Service]
Type=forking
User=nexus
LimitNOFILE=65536
EnvironmentFile=/etc/nexus.env
ExecStart=$${NEXUS_HOME}/bin/nexus start
ExecStop=$${NEXUS_HOME}/bin/nexus stop
Restart=on-failure
RestartSec=30
TimeoutSec=600

[Install]
WantedBy=multi-user.target
UNIT
chmod 644 /etc/systemd/system/nexus.service
systemctl daemon-reload

# SELinux stays enforcing: label the program files so systemd may execute them.
if command -v getenforce > /dev/null && [ "$(getenforce)" = "Enforcing" ]; then
    command -v semanage > /dev/null || dnf -y install policycoreutils-python-utils
    semanage fcontext -a -t bin_t "$${NEXUS_HOME}(/.*)?" 2> /dev/null || semanage fcontext -m -t bin_t "$${NEXUS_HOME}(/.*)?"
    restorecon -RF "$${NEXUS_HOME}"
    restorecon -R "$${SONATYPE_WORK}"
    echo "SELinux enforcing: $${NEXUS_HOME} labelled bin_t"
fi

%{ if tls_mode == "gateway" ~}
# 8081 is open only to the gateway and nodes subnets (defense in depth beside the NSGs); other ports are untouched.
if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --remove-port=8081/tcp || true
%{ for cidr in app_port_sources ~}
    firewall-cmd --permanent --add-rich-rule='rule family="ipv4" source address="${cidr}" port port="8081" protocol="tcp" accept'
%{ endfor ~}
    firewall-cmd --reload
else
    echo "NOTE: firewalld is not running; 8081 is protected by the network security groups only"
fi
%{ endif ~}
echo "Nexus configured (node ${node_index}, clustered=${clustered}, db=${database_type}, tls=${tls_mode})"
