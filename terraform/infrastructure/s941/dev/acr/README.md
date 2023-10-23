# ACR Setup (WIP!)
## TODO:
- Get cache ACR up and running
  - [x] Set up Cache ACR
  - [x] Make sure our DNS zone have a records to ACR and Storage (needs 2 IP addresses)
  - [x] Make sure our DNS zone have a link to both the vnet hub, and AKS vnet
  - [ ] Add loops for all clusters
  - [ ] Figgure out a way to get credentials from our Identity in to Kubernetes secrets
  - [ ] Move other ACRs in to Terraform 

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
