#!/bin/bash
# Copyright (c) 2008-present Sonatype, Inc. Renders the cloud-init templates and syntax-checks every script.
set -euo pipefail

SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
MODULE_DIR=$(cd "${SCRIPT_DIR}/../modules/cloud_init" && pwd)
WORK=$(cd "$(mktemp -d)" && pwd -P)
trap '[ -n "${KEEP_RENDERED:-}" ] && echo "kept ${WORK}" >&2 || rm -rf "${WORK}"' EXIT

# Scenarios: single node behind nginx, and a three-node gateway cluster; both PostgreSQL + Azure blobs.
render() {
    local name="$1" cluster_size="$2" tls_mode="$3" clustered="$4"
    local dir="${WORK}/${name}"
    mkdir -p "${dir}"
    # A relative source keeps the module in place; absolute sources are copied and lose the templates.
    local source
    source=$(python3 -c 'import os,sys; print(os.path.relpath(sys.argv[1], sys.argv[2]))' "$(cd "${MODULE_DIR}" && pwd -P)" "${dir}")
    cat > "${dir}/main.tf" <<TF
module "ci" {
  source                 = "${source}"
  cluster_size           = ${cluster_size}
  artifacts_account      = "nxrmartifacts"
  artifacts_container    = "nxrm-assets"
  tarball_blob           = "nexus-3.0.0-unix.tar.gz"
  license_blob           = "nexus.lic"
  secrets_blob           = "secrets/nxrm-secrets.json"
  identity_client_id     = "00000000-0000-0000-0000-000000000003"
  java_min_heap          = "16g"
  java_max_heap          = "16g"
  java_max_direct_memory = "8g"
  clustered              = ${clustered}
  database_type          = "postgres"
  db_host                = "nxrm-pg.postgres.database.azure.com"
  db_name                = "nxrm_config"
  db_user                = "nexus"
  blobstore_type         = "azure"
  blob_account           = "nxrmblobs"
  blob_container         = "nxrm-blobs"
  tls_mode               = "${tls_mode}"
  dns_name               = "nexus.example.com"
  certificate_secret_id  = "https://kv-test.vault.azure.net/secrets/nexus-cert"
  base_url               = "https://nexus.example.com"
}
TF
    terraform -chdir="${dir}" init -backend=false -input=false > /dev/null
    echo 'jsonencode({scripts = module.ci.rendered_scripts, custom_data = module.ci.custom_data})' |
        terraform -chdir="${dir}" console | jq -r 'fromjson' > "${dir}/rendered.json"

    local count
    count=$(jq '.custom_data | length' "${dir}/rendered.json")
    [ "${count}" -eq "${cluster_size}" ] || { echo "FAIL ${name}: ${count} custom_data elements, expected ${cluster_size}"; exit 1; }
    for i in $(seq 0 $((count - 1))); do
        jq -r ".custom_data[${i}]" "${dir}/rendered.json" | base64 -d > "${dir}/cloud-init-${i}.yaml"
        head -1 "${dir}/cloud-init-${i}.yaml" | grep -qx '#cloud-config' || { echo "FAIL ${name}: node ${i} is not cloud-config"; exit 1; }
        echo "ok   ${name}: node ${i} cloud-config"
    done
    for script in $(jq -r '.scripts | keys[]' "${dir}/rendered.json"); do
        jq -r --arg s "${script}" '.scripts[$s]' "${dir}/rendered.json" > "${dir}/${script}.sh"
        bash -n "${dir}/${script}.sh" || { echo "FAIL ${name}: bash -n ${script}"; exit 1; }
        if [ -n "${SHELLCHECK}" ]; then
            "${SHELLCHECK}" -S warning "${dir}/${script}.sh" || { echo "FAIL ${name}: shellcheck ${script}"; exit 1; }
        fi
        echo "ok   ${name}: ${script}"
    done
    # The certificate renew script is a quoted heredoc inside nginx-tls; lint it on its own.
    if [ -f "${dir}/nginx-tls.sh" ]; then
        sed -n "/<<'RENEW'$/,/^RENEW$/p" "${dir}/nginx-tls.sh" | sed '1d;$d' > "${dir}/nxrm-cert-renew.sh"
        [ -s "${dir}/nxrm-cert-renew.sh" ] || { echo "FAIL ${name}: renew script not found in nginx-tls"; exit 1; }
        bash -n "${dir}/nxrm-cert-renew.sh" || { echo "FAIL ${name}: bash -n nxrm-cert-renew"; exit 1; }
        if [ -n "${SHELLCHECK}" ]; then
            "${SHELLCHECK}" -S warning "${dir}/nxrm-cert-renew.sh" || { echo "FAIL ${name}: shellcheck nxrm-cert-renew"; exit 1; }
        fi
        echo "ok   ${name}: nxrm-cert-renew (embedded)"
    fi
}

# Round-trips metacharacter passwords through the escaping helpers exactly as rendered.
test_secret_escaping() {
    local dir="$1" helpers jq_line t="${WORK}/escaping" i=0 pw got want
    mkdir -p "${t}"
    helpers=$(grep -E '^(env_quote|prop_escape)\(\) ' "${dir}/configure-nexus.sh" || true)
    jq_line=$(grep -E "^jq -r '\.nexus_admin_password \| gsub" "${dir}/create-blobstore.sh" || true)
    [ "$(printf '%s\n' "${helpers}" | grep -c .)" -eq 2 ] || { echo "FAIL escaping: helpers not found in configure-nexus"; exit 1; }
    [ -n "${jq_line}" ] || { echo "FAIL escaping: curl-config jq line not found in create-blobstore"; exit 1; }
    eval "${helpers}"

    local passwords=(
        'Adm$1n!'"'"'"p\w'
        'a b#c d'
        'back`tick`$(id)${HOME}'
        '100%{x}%%s'
        '\"\\$`'
        ' leading and trailing '
        'ends-with-backslash\'
        '#hash-first! \n \t'
    )
    : > "${t}/store.properties"
    for pw in "${passwords[@]}"; do
        # systemd EnvironmentFile form: exact escaped text, valid shell, and sourcing restores the value
        got=$(env_quote "${pw}")
        want=$(python3 -I -c 'import re,sys; print("\"" + re.sub(r"([\\\"$`])", r"\\\1", sys.argv[1]) + "\"", end="")' "${pw}")
        [ "${got}" = "${want}" ] || { echo "FAIL env_quote #${i}: got [${got}] want [${want}]"; exit 1; }
        printf 'NEXUS_SECURITY_INITIAL_PASSWORD=%s\n' "${got}" > "${t}/nexus.env"
        bash -n "${t}/nexus.env" || { echo "FAIL env_quote #${i}: bash -n"; exit 1; }
        got=$(bash -c '. "$1"; printf "%s" "${NEXUS_SECURITY_INITIAL_PASSWORD}"' _ "${t}/nexus.env")
        [ "${got}" = "${pw}" ] || { echo "FAIL env_quote #${i}: sourced [${got}] want [${pw}]"; exit 1; }

        # Java properties form
        got=$(prop_escape "${pw}")
        want=$(python3 -I -c 'import sys; print(sys.argv[1].replace("\\", "\\\\").replace(" ", "\\ "), end="")' "${pw}")
        [ "${got}" = "${want}" ] || { echo "FAIL prop_escape #${i}: got [${got}] want [${want}]"; exit 1; }
        printf 'p%s=%s\n' "${i}" "${got}" >> "${t}/store.properties"
        printf '%s' "${pw}" > "${t}/pw-${i}"

        # curl config form, built by the same jq expression from a JSON secrets file
        jq -n --arg p "${pw}" '{nexus_admin_password: $p}' > "${t}/secrets.json"
        got=$(SECRETS_FILE="${t}/secrets.json" CURL_AUTH="${t}/curl-${i}.cfg" bash -c "${jq_line}" && cat "${t}/curl-${i}.cfg")
        want=$(python3 -I -c 'import sys; print("user = \"admin:" + sys.argv[1].replace("\\", "\\\\").replace("\"", "\\\"") + "\"")' "${pw}")
        [ "${got}" = "${want}" ] || { echo "FAIL curl config #${i}: got [${got}] want [${want}]"; exit 1; }
        i=$((i + 1))
    done
    echo "ok   escaping: env_quote exact form + bash -n + source round-trip (${i} passwords)"
    echo "ok   escaping: prop_escape and curl-config exact form (${i} passwords)"

    # Real parsers: java.util.Properties and curl sending Basic auth to a local one-shot listener
    if command -v java > /dev/null; then
        cat > "${t}/Props.java" <<'JAVA'
import java.io.FileReader;
import java.nio.file.Files;
import java.nio.file.Path;
import java.util.Properties;
public class Props {
    public static void main(String[] a) throws Exception {
        Properties p = new Properties();
        p.load(new FileReader(a[0]));
        for (int i = 0; i < Integer.parseInt(a[1]); i++) {
            if (!p.getProperty("p" + i).equals(Files.readString(Path.of(a[2] + "/pw-" + i)))) {
                System.out.println("FAIL java properties #" + i + ": [" + p.getProperty("p" + i) + "]");
                System.exit(1);
            }
        }
    }
}
JAVA
        java "${t}/Props.java" "${t}/store.properties" "${i}" "${t}" || exit 1
        echo "ok   escaping: java.util.Properties restores all ${i} passwords"
    else
        echo "skip escaping: java not installed, Properties round-trip not run"
    fi
    cat > "${t}/listener.py" <<'LISTENER'
import base64, http.server, sys
class H(http.server.BaseHTTPRequestHandler):
    def do_GET(self):
        with open(sys.argv[1], "ab") as f:
            f.write(base64.b64decode(self.headers["Authorization"].split()[1]) + b"\0")
        self.send_response(204)
        self.end_headers()
    def log_message(self, *a):
        pass
s = http.server.HTTPServer(("127.0.0.1", 0), H)
print(s.server_address[1], flush=True)
for _ in range(int(sys.argv[2])):
    s.handle_request()
LISTENER
    : > "${t}/received"
    python3 -I "${t}/listener.py" "${t}/received" "${i}" > "${t}/port" &
    local listener=$! port="" n
    for _ in $(seq 1 50); do port=$(cat "${t}/port"); [ -n "${port}" ] && break; sleep 0.1; done
    for n in $(seq 0 $((i - 1))); do
        curl -sS -K "${t}/curl-${n}.cfg" -o /dev/null "http://127.0.0.1:${port}/"
    done
    wait "${listener}"
    n=0
    while IFS= read -r -d '' got; do
        [ "${got}" = "admin:$(cat "${t}/pw-${n}")" ] || { echo "FAIL curl config #${n}: server received [${got}]"; exit 1; }
        n=$((n + 1))
    done < "${t}/received"
    [ "${n}" -eq "${i}" ] || { echo "FAIL curl config: ${n} of ${i} requests received"; exit 1; }
    echo "ok   escaping: curl sent the exact admin:<password> for all ${i} passwords"
}

SHELLCHECK=$(command -v shellcheck || true)
if [ -n "${SHELLCHECK}" ]; then
    echo "shellcheck: $(${SHELLCHECK} --version | sed -n 's/^version: //p') (-S warning)"
else
    echo "shellcheck: not installed, running bash -n only"
fi

render single-nginx 1 nginx false
render cluster-gateway 3 gateway true
test_secret_escaping "${WORK}/single-nginx"
echo OK
