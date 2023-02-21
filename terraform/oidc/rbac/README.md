## How to use (locally)

Run below commands to Initialize terraform in current directory

```sh
# Initialize terraform
terraform init
```

Run below commands to deploy

```sh
terraform apply --var-file=../../radix-zone/radix_zone_dev.tfvars
```

Run below commands to destroy

```sh
terraform destroy --var-file=../../radix-zone/radix_zone_dev.tfvars
```
