#!/bin/bash
# Copyright (c) 2008-present Sonatype, Inc. Creates the Azure blob store once (node 0), authenticated by managed identity.
set -euo pipefail
set +x
umask 077

NEXUS_URL="http://127.0.0.1:8081"
BLOBSTORE_NAME="default"

# Shared helpers: blob_get and kv_get
# shellcheck source=/dev/null
. /opt/nxrm-bootstrap/lib.sh

writable=false
for i in $(seq 1 90); do
    if curl -sf --connect-timeout 10 --max-time 20 -o /dev/null "$${NEXUS_URL}/service/rest/v1/status/writable"; then
        writable=true
        break
    fi
    echo "Waiting for Nexus to accept writes ($${i}/90)..."
    sleep 10
done
if [ "$${writable}" != "true" ]; then
    echo "ERROR: Nexus did not accept writes after 15 minutes; check journalctl -u nexus" >&2
    exit 1
fi

SECRETS_FILE=$(mktemp /run/nxrm-secrets.XXXXXX)
CURL_AUTH=$(mktemp /run/nxrm-curl.XXXXXX)
trap 'rm -f "$${SECRETS_FILE}" "$${CURL_AUTH}"' EXIT
kv_get "${admin_secret_name}" "$${SECRETS_FILE}"
# curl config file keeps the password off the command line; escape \ and " for its quoting.
jq -r '.value | gsub("\\\\"; "\\\\") | gsub("\""; "\\\"") | "user = \"admin:" + . + "\""' "$${SECRETS_FILE}" > "$${CURL_AUTH}"
rm -f "$${SECRETS_FILE}"

STORE_URL="$${NEXUS_URL}/service/rest/v1/blobstores/azure/$${BLOBSTORE_NAME}"
RESPONSE=/run/nxrm-blobstore-response.json
trap 'rm -f "$${SECRETS_FILE}" "$${CURL_AUTH}" "$${RESPONSE}"' EXIT

# REST may accept and ignore an unknown field, so read the store back and check both settings.
# Keys are searched anywhere in the response, so the check does not depend on the JSON layout.
verify_blobstore() {
    local http
    http=$(curl -sS --connect-timeout 10 --max-time 20 -K "$${CURL_AUTH}" -o "$${RESPONSE}" -w '%%{http_code}' "$${STORE_URL}" || true)
    if [ "$${http}" != "200" ]; then
        echo "ERROR: reading blob store $${BLOBSTORE_NAME} back returned HTTP $${http}" >&2
        return 1
    fi
    if jq -e '[.. | objects | select(has("preSignedUrlEnabled")) | .preSignedUrlEnabled] | any(. == true)' "$${RESPONSE}" > /dev/null &&
        jq -e '[.. | objects | select(has("authenticationMethod")) | .authenticationMethod] | any(. == "MANAGEDIDENTITY")' "$${RESPONSE}" > /dev/null; then
        echo "Blob store $${BLOBSTORE_NAME}: managed identity and pre-signed URLs confirmed"
        return 0
    fi
    echo "ERROR: blob store $${BLOBSTORE_NAME} lacks preSignedUrlEnabled=true or MANAGEDIDENTITY; Nexus returned:" >&2
    jq 'walk(if type == "object" and has("accountKey") then .accountKey = "<redacted>" else . end)' "$${RESPONSE}" >&2 || true
    return 1
}

http=$(curl -sS --connect-timeout 10 --max-time 20 -K "$${CURL_AUTH}" -o /dev/null -w '%%{http_code}' "$${STORE_URL}" || true)
if [ "$${http}" = "200" ]; then
    echo "Blob store $${BLOBSTORE_NAME} already exists"
    verify_blobstore
    exit 0
fi

# Payload accepted by Nexus 3.98 (AzureBlobStoreApiModel); verify_blobstore reads it back.
PAYLOAD=$(jq -n \
    --arg name "$${BLOBSTORE_NAME}" \
    --arg account "${blob_account}" \
    --arg container "${blob_container}" \
    '{name: $name,
      bucketConfiguration: {
        accountName: $account,
        containerName: $container,
        authentication: {authenticationMethod: "MANAGEDIDENTITY"},
        preSignedUrlEnabled: true
      }}')

http=$(printf '%s' "$${PAYLOAD}" | curl -sS --connect-timeout 10 --max-time 60 -K "$${CURL_AUTH}" -o "$${RESPONSE}" -w '%%{http_code}' \
    -H "Content-Type: application/json" -X POST --data-binary @- "$${NEXUS_URL}/service/rest/v1/blobstores/azure" || true)
case "$${http}" in
    200 | 201 | 204)
        echo "Blob store $${BLOBSTORE_NAME} created on ${blob_account}/${blob_container}"
        ;;
    *)
        echo "ERROR: blob store creation returned HTTP $${http}: $(head -c 2000 "$${RESPONSE}")" >&2
        exit 1
        ;;
esac
verify_blobstore
