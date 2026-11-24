# Sonatype Nexus Repository Reference Architectures

Terraform templates that deploy Sonatype Nexus Repository reference architectures on public clouds.
Each cloud has its own folder with a self-contained template, tfvars files, and instructions.

| Cloud | Folder | Instructions |
|---|---|---|
| AWS | [`aws/`](aws/) | [aws/README.md](aws/README.md) |
| Azure | [`azure/`](azure/) | [azure/README.md](azure/README.md) |

Run Terraform from inside the cloud folder, for example `cd aws` or `cd azure`.

## Where did the AWS files go?

The AWS template previously lived at the root of this repository. It now lives under `aws/`
(`aws/main.tf`, `aws/tfvars/`, `aws/modules/`, and so on) with no functional change. Update any
paths in your own scripts accordingly. To use the original root layout, check out the
`aws-v1.0.0` tag.

## License

See [LICENSE](LICENSE).
