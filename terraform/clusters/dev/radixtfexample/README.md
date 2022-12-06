## How to use (locally)

1. cluster name will be the same as folder name
2. Copy `.env.template`, rename it to `.env`, and populate accordingly

Run below commands to deploy
```sh
# Initialize terraform
# This will connect terraform backend to Azure
terraform init -backend-config=.env

# Will deploy main.tf
terraform apply --var-file=../../../radix-zone/radix_zone_dev.tfvars
```
Run below commands to destroy
```sh
# Initialize terraform
# This will connect terraform backend to Azure
terraform init -backend-config=.env

# Will destroy main.tf
terraform destroy --var-file=../../../radix-zone/radix_zone_dev.tfvars
```