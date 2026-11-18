#cloud-config
# Copyright (c) 2008-present Sonatype, Inc. Writes the Nexus bootstrap scripts and runs them in order.
write_files:
%{ for name, content in scripts ~}
  - path: /opt/nxrm-bootstrap/${name}.sh
    owner: root:root
    permissions: "0700"
    encoding: b64
    content: ${content}
%{ endfor ~}
runcmd:
  - [ /bin/bash, -c, "umask 077; for s in ${join(" ", run_order)}; do echo \"=== $(date -Is) start $s\"; /opt/nxrm-bootstrap/$s.sh || { echo \"=== $(date -Is) FAILED $s\"; exit 1; }; done >> /var/log/nxrm-bootstrap.log 2>&1; echo \"=== $(date -Is) bootstrap complete\" >> /var/log/nxrm-bootstrap.log" ]
