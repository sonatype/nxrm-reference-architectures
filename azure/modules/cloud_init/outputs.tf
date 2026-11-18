#
# Copyright (c) 2008-present Sonatype, Inc.
#
# All rights reserved. Includes the third-party code listed at http://links.sonatype.com/products/nexus/pro/attributions
# Sonatype and Sonatype Nexus are trademarks of Sonatype, Inc. Apache Maven is a trademark of the Apache Foundation.
# M2Eclipse is a trademark of the Eclipse Foundation. All other trademarks are the property of their respective owners.
#

output "custom_data" {
  description = "Base64 cloud-config per node; the list position is the node index"
  value       = local.custom_data
}

output "rendered_scripts" {
  description = "Script name to rendered text for node 0 (tests and check-templates.sh)"
  value       = local.node_scripts[0]
}
