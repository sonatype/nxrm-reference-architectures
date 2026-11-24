# Existing network example

A self-contained Terraform configuration that builds the kind of network a customer already has, so you can try the template's `create_network = false` mode or copy the pieces you are missing.

It creates its own resource group, a virtual network and three subnets:

| Subnet | What it has |
|---|---|
| `nodes` | `Microsoft.Storage` and `Microsoft.KeyVault` service endpoints, a NAT gateway for outbound access, an NSG |
| `db` | Empty, delegated to `Microsoft.DBforPostgreSQL/flexibleServers` (join action declared) |
| `gateway` | Dedicated, with an NSG that allows `GatewayManager` 65200-65535, clients on 80/443 and `AzureLoadBalancer` |

The nodes NSG allows node to node, the gateway subnet on 8081, clients on 80/443 and `AzureLoadBalancer`.

## Use

```bash
cd azure/examples/existing-network
terraform init
terraform apply -var azure_subscription_id=<subscription-id>
terraform output
```

Then, in the template's `terraform.tfvars` (the folder above this one):

```hcl
create_network    = false
nodes_subnet_id   = "<nodes_subnet_id output>"
db_subnet_id      = "<db_subnet_id output>"
gateway_subnet_id = "<gateway_subnet_id output>"
```

Narrow `client_cidrs` (default `0.0.0.0/0`) to your client ranges. Destroy the template first, then this example (`terraform destroy`), because the template's resources use these subnets.
