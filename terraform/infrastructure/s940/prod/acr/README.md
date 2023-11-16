# ACR Buildah Cache Setup

**IMPORTANT**: This script will recreate passwords to he container registry, 
it might take a few seconds before the secrets are available in the cluster, 
and it might cause some downime for Buildah.

The generated password is uploaded to a Azure Key Vault, and inserted into the cluster.
The AKS Bootstraping/Migration script will *also* copy the secret from the key vault to the cluster.

Changes here must be reflected in the relevant scripts.

## How to use (locally)

1. cluster name will be the same as folder name
2. Copy `.env.template`, rename it to `.env`, and populate accordingly

Run below commands to Initialize terraform in current directory

```sh
# Initialize terraform
# This will connect terraform backend to Azure
terraform init -backend-config=.env
```

Run below commands to plan

```sh
# Will plan main.tf
terraform plan --var-file=../../../../radix-zone/radix_zone_dev.tfvars
```

Run below commands to deploy

```sh
# Will deploy main.tf
terraform apply --var-file=../../../../radix-zone/radix_zone_dev.tfvars
```

Run below commands to destroy

```sh
# Will destroy main.tf
terraform destroy --var-file=../../../../radix-zone/radix_zone_dev.tfvars
```
