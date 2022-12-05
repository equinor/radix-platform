<!-- BEGIN_TF_DOCS -->
## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | ~> 3.22.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | ~> 3.22.0 |

## Modules

| Name | Source | Version |
|------|--------|---------|
| aks | [radix-terraform-azurerm-aks](https://github.com/equinor/radix-terraform-azurerm-aks) | development |

## Resources

| Name | Type |
|------|------|
| [azurerm_redis_cache.redis_cache_web_console](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/redis_cache) | resource |
| [azurerm_private_dns_zone_virtual_network_link.cluster_link](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/cluster_link) | resource |

## How to use

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
<!-- END_TF_DOCS -->
