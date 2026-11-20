#!/bin/bash
# Copyright (c) 2008-present Sonatype, Inc. Nginx TLS proxy for single-node sizes; certificate pulled from Key Vault.
set -euo pipefail

dnf -y install nginx openssl jq curl

cat > /etc/nxrm-cert.conf <<'CONF'
CERT_SECRET_ID="${certificate_secret_id}"
IDENTITY_CLIENT_ID="${identity_client_id}"
CONF
chmod 600 /etc/nxrm-cert.conf

[ -f /etc/nginx/nginx.conf.orig ] || cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.orig
cat > /etc/nginx/nginx.conf <<'NGINX'
user nginx;
worker_processes auto;
worker_rlimit_nofile 65536;
error_log /var/log/nginx/error.log notice;
pid /run/nginx.pid;
include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 4096;
}

http {
    include /etc/nginx/mime.types;
    default_type application/octet-stream;
    access_log /var/log/nginx/access.log;
    sendfile on;
    keepalive_timeout 65;
    server_tokens off;
    include /etc/nginx/conf.d/*.conf;
}
NGINX

cat > /etc/nginx/conf.d/nexus.conf <<'NGINX'
server {
    listen 80 default_server;
    listen [::]:80 default_server;
    server_name _;
    return 301 https://${dns_name}$request_uri;
}

server {
    listen 443 ssl default_server;
    listen [::]:443 ssl default_server;
    server_name ${dns_name};

    ssl_certificate /etc/nginx/tls/fullchain.pem;
    ssl_certificate_key /etc/nginx/tls/privkey.pem;
    ssl_protocols TLSv1.2 TLSv1.3;
    ssl_prefer_server_ciphers off;
    ssl_session_cache shared:SSL:10m;
    ssl_session_timeout 1d;
    add_header Strict-Transport-Security "max-age=31536000" always;

    client_max_body_size 0;
    proxy_request_buffering off;

    location / {
        proxy_pass http://127.0.0.1:8081;
        proxy_http_version 1.1;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto https;
        proxy_connect_timeout 60s;
        proxy_send_timeout 900s;
        proxy_read_timeout 900s;
    }
}
NGINX
rm -f /etc/nginx/conf.d/default.conf

# Fetches the PFX secret, converts it to PEM and reloads nginx only when it changed.
cat > /usr/local/sbin/nxrm-cert-renew.sh <<'RENEW'
#!/bin/bash
set -euo pipefail
set +x
umask 077
# shellcheck disable=SC1091
. /etc/nxrm-cert.conf
TLS_DIR=/etc/nginx/tls
ATTEMPTS="$${NXRM_CERT_ATTEMPTS:-10}"
WORK=$(mktemp -d /run/nxrm-cert.XXXXXX)
trap 'rm -rf "$${WORK}"' EXIT

http=000
for attempt in $(seq 1 "$${ATTEMPTS}"); do
    token=$(curl -sS --connect-timeout 10 --max-time 20 -H Metadata:true "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=https%3A%2F%2Fvault.azure.net&client_id=$${IDENTITY_CLIENT_ID}" | jq -r '.access_token // empty' || true)
    if [ -n "$${token}" ]; then
        http=$(printf 'header = "Authorization: Bearer %s"\n' "$${token}" | curl -sS --connect-timeout 10 --max-time 20 -K - -w '%%{http_code}' -o "$${WORK}/secret.json" "$${CERT_SECRET_ID%/}?api-version=7.4" || true)
        [ "$${http}" = "200" ] && break
    fi
    echo "attempt $${attempt}/$${ATTEMPTS}: Key Vault HTTP $${http} (access policy or RBAC may still be propagating)"
    sleep 15
done
if [ "$${http}" != "200" ]; then
    echo "ERROR: could not read the certificate secret, last HTTP $${http}" >&2
    exit 1
fi

CONTENT_TYPE=$(jq -r '.contentType // empty' "$${WORK}/secret.json")
if [ "$${CONTENT_TYPE}" != "application/x-pkcs12" ]; then
    echo "ERROR: certificate secret has contentType '$${CONTENT_TYPE}'; import the certificate into Key Vault as PKCS#12 (PFX), not PEM" >&2
    exit 1
fi
jq -r '.value' "$${WORK}/secret.json" | base64 -d > "$${WORK}/cert.pfx"
rm -f "$${WORK}/secret.json"
# Key Vault exports certificate secrets as a PFX with an empty password.
pkcs12() {
    openssl pkcs12 -in "$${WORK}/cert.pfx" -passin pass: "$@" 2> /dev/null ||
        openssl pkcs12 -legacy -in "$${WORK}/cert.pfx" -passin pass: "$@"
}
pkcs12 -clcerts -nokeys -out "$${WORK}/leaf.pem"
pkcs12 -cacerts -nokeys -out "$${WORK}/chain.pem"
pkcs12 -nocerts -nodes -out "$${WORK}/privkey.pem"
cat "$${WORK}/leaf.pem" "$${WORK}/chain.pem" > "$${WORK}/fullchain.pem"
openssl x509 -in "$${WORK}/fullchain.pem" -noout -subject -enddate
if [ "$(openssl x509 -in "$${WORK}/leaf.pem" -noout -pubkey)" != "$(openssl pkey -in "$${WORK}/privkey.pem" -pubout)" ]; then
    echo "ERROR: the private key in the certificate secret does not match the certificate" >&2
    exit 1
fi

if cmp -s "$${WORK}/fullchain.pem" "$${TLS_DIR}/fullchain.pem" && cmp -s "$${WORK}/privkey.pem" "$${TLS_DIR}/privkey.pem"; then
    echo "Certificate unchanged"
    exit 0
fi
mkdir -p "$${TLS_DIR}" "$${WORK}/previous"
chmod 700 "$${TLS_DIR}"
for f in fullchain.pem privkey.pem; do
    if [ -f "$${TLS_DIR}/$${f}" ]; then cp -p "$${TLS_DIR}/$${f}" "$${WORK}/previous/$${f}"; fi
done
# Puts the previous PEMs back (or removes the new ones on first boot).
rollback_certificate() {
    for f in fullchain.pem privkey.pem; do
        if [ -f "$${WORK}/previous/$${f}" ]; then
            install -m 600 -o root -g root "$${WORK}/previous/$${f}" "$${TLS_DIR}/$${f}"
        else
            rm -f "$${TLS_DIR}/$${f}"
        fi
    done
}
install -m 600 -o root -g root "$${WORK}/fullchain.pem" "$${TLS_DIR}/fullchain.pem"
install -m 600 -o root -g root "$${WORK}/privkey.pem" "$${TLS_DIR}/privkey.pem"
if command -v restorecon > /dev/null; then restorecon -R "$${TLS_DIR}"; fi
if ! nginx -t; then
    rollback_certificate
    echo "ERROR: nginx rejected the new certificate; previous certificate kept" >&2
    exit 1
fi
echo "Certificate installed"
if systemctl is-active --quiet nginx; then
    systemctl reload nginx
fi
RENEW
chmod 700 /usr/local/sbin/nxrm-cert-renew.sh

# First boot: Key Vault RBAC can take minutes to propagate, so retry up to 10 minutes.
if ! NXRM_CERT_ATTEMPTS=40 /usr/local/sbin/nxrm-cert-renew.sh; then
    echo "ERROR: TLS certificate not installed; check the Key Vault access of the node identity and /var/log/nxrm-bootstrap.log, then re-run the deployment or replace the VM" >&2
    exit 1
fi

cat > /etc/systemd/system/nxrm-cert-renew.service <<'UNIT'
[Unit]
Description=Refresh the Nexus TLS certificate from Key Vault
Wants=network-online.target
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/local/sbin/nxrm-cert-renew.sh
UNIT

cat > /etc/systemd/system/nxrm-cert-renew.timer <<'UNIT'
[Unit]
Description=Daily Nexus TLS certificate refresh

[Timer]
OnCalendar=daily
RandomizedDelaySec=1h
Persistent=true

[Install]
WantedBy=timers.target
UNIT

# nginx must be allowed to connect to the Nexus port under SELinux.
if command -v getenforce > /dev/null && [ "$(getenforce)" != "Disabled" ]; then
    setsebool -P httpd_can_network_connect 1
fi
if systemctl is-active --quiet firewalld; then
    firewall-cmd --permanent --add-service=http --add-service=https
    firewall-cmd --reload
fi

systemctl daemon-reload
nginx -t
systemctl enable --now nginx
systemctl enable --now nxrm-cert-renew.timer
echo "nginx TLS proxy ready for ${dns_name}"
