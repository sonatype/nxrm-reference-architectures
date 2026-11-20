#!/bin/bash
# Copyright (c) 2008-present Sonatype, Inc. Sourced by the bootstrap scripts: reads from Storage and Key Vault with the VM identity.

# Prints the HTTP status of one GET made with a managed identity token for the resource in $1 ("000" when no token yet).
# A token minted before a role assignment propagates has no grant, so every call mints a new one.
identity_get() {
    local resource="$1" url="$2" dest="$3" max_time="$4" token
    shift 4
    token=$(curl -sS --connect-timeout 10 --max-time 20 -H Metadata:true "http://169.254.169.254/metadata/identity/oauth2/token?api-version=2018-02-01&resource=$${resource}&client_id=${identity_client_id}" | jq -r '.access_token // empty' || true)
    if [ -z "$${token}" ]; then
        echo 000
        return 0
    fi
    printf 'header = "Authorization: Bearer %s"\n' "$${token}" | curl -sS --connect-timeout 10 --max-time "$${max_time}" -K - -w '%%{http_code}' -o "$${dest}" "$@" "$${url}" || true
}

# Downloads one blob of the artifacts container to $2; $3 is the transfer limit in seconds.
blob_get() {
    local blob="$1" dest="$2" max_time="$${3:-20}" http=000 attempt
    for attempt in $(seq 1 10); do
        http=$(identity_get "https%3A%2F%2Fstorage.azure.com" "https://${artifacts_account}.blob.core.windows.net/${artifacts_container}/$${blob}" "$${dest}" "$${max_time}" -H "x-ms-version: 2021-08-06")
        [ "$${http}" = "200" ] && return 0
        echo "attempt $${attempt}: HTTP $${http} for $${blob} (role assignment may still be propagating)"
        rm -f "$${dest}"
        sleep 15
    done
    echo "ERROR: download of $${blob} failed, last HTTP $${http}" >&2
    return 1
}

# Reads one Key Vault secret (JSON response) to $2; role assignments can take minutes to propagate.
kv_get() {
    local name="$1" dest="$2" http=000 attempt
    for attempt in $(seq 1 20); do
        http=$(identity_get "https%3A%2F%2Fvault.azure.net" "https://${key_vault_name}.vault.azure.net/secrets/$${name}?api-version=7.4" "$${dest}" 20)
        [ "$${http}" = "200" ] && return 0
        echo "attempt $${attempt}: Key Vault HTTP $${http} for $${name} (role assignment may still be propagating)"
        rm -f "$${dest}"
        sleep 15
    done
    echo "ERROR: could not read Key Vault secret $${name}, last HTTP $${http}" >&2
    return 1
}
