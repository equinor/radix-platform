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

<!-- BEGIN_TF_DOCS -->

## Requirements

| Name | Version |
|------|---------|
| <a name="requirement_terraform"></a> [terraform](#requirement\_terraform) | >= 1.3.0 |
| <a name="requirement_azuread"></a> [azuread](#requirement\_azuread) | ~> 2.15.0 |
| <a name="requirement_azurerm"></a> [azurerm](#requirement\_azurerm) | >= 3.39.0 |

## Providers

| Name | Version |
|------|---------|
| <a name="provider_azuread"></a> [azuread](#provider\_azuread) | 2.15.0 |
| <a name="provider_azurerm"></a> [azurerm](#provider\_azurerm) | 3.43.0 |

## Modules

No modules.

## Resources

| Name | Type |
|------|------|
| [azuread_application.APP_GITHUB_ACTION_CLUSTER](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application) | resource |
| [azuread_application_federated_identity_credential.APP_GITHUB_DEV_CLUSTER_FED](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/application_federated_identity_credential) | resource |
| [azuread_service_principal.SP_GITHUB_ACTION_CLUSTER](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/resources/service_principal) | resource |
| [azurerm_role_assignment.RA_CONTRIBUTOR_ROLE](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.RA_STORAGE_BLOB_DATA_OWNER](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_role_assignment.RA_USER_ACCESS_ADMINISTRATOR](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/role_assignment) | resource |
| [azurerm_storage_account.SA_INFRASTRUCTURE](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_account) | resource |
| [azurerm_storage_container.SA_INFRASTRUCTURE_CONTAINER_CLUSTERS](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container) | resource |
| [azurerm_storage_container.SA_INFRASTRUCTURE_CONTAINER_INFRASTRUCTURE](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/storage_container) | resource |
| [azuread_group.radix_group](https://registry.terraform.io/providers/hashicorp/azuread/latest/docs/data-sources/group) | data source |
| [azurerm_client_config.CLIENT_CONFIG](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/client_config) | data source |
| [azurerm_subscription.AZ_SUBSCRIPTION](https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/data-sources/subscription) | data source |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| <a name="input_AAD_RADIX_GROUP"></a> [AAD\_RADIX\_GROUP](#input\_AAD\_RADIX\_GROUP) | Radix group name | `string` | n/a | yes |
| <a name="input_APP_GITHUB_ACTION_CLUSTER_NAME"></a> [APP\_GITHUB\_ACTION\_CLUSTER\_NAME](#input\_APP\_GITHUB\_ACTION\_CLUSTER\_NAME) | Application name | `string` | n/a | yes |
| <a name="input_AZ_SUBSCRIPTION_ID"></a> [AZ\_SUBSCRIPTION\_ID](#input\_AZ\_SUBSCRIPTION\_ID) | Azure subscription id | `string` | n/a | yes |
| <a name="input_GH_ENVIRONMENT"></a> [GH\_ENVIRONMENT](#input\_GH\_ENVIRONMENT) | Github environment | `string` | n/a | yes |
| <a name="input_GH_ORGANIZATION"></a> [GH\_ORGANIZATION](#input\_GH\_ORGANIZATION) | Github organization | `string` | n/a | yes |
| <a name="input_GH_REPOSITORY"></a> [GH\_REPOSITORY](#input\_GH\_REPOSITORY) | Github repository | `string` | n/a | yes |
| <a name="input_storage_accounts"></a> [storage\_accounts](#input\_storage\_accounts) | n/a | <pre>map(object({<br>    name                              = string                          # Mandatory<br>    rg_name                           = string                          # Mandatory<br>    location                          = optional(string, "northeurope") # Optional<br>    kind                              = optional(string, "StorageV2")   # Optional<br>    repl                              = optional(string, "LRS")         # Optional<br>    tier                              = optional(string, "Standard")    # Optional<br>    backup_center                     = optional(bool, false)           # Optional      <br>    life_cycle                        = optional(bool, true)<br>    firewall                          = optional(bool, true)<br>    container_delete_retention_policy = optional(bool, true)<br>    tags                              = optional(map(string), {})<br>    allow_nested_items_to_be_public   = optional(bool, false) #GUI: Configuration Allow Blob public access<br>    shared_access_key_enabled         = optional(bool, true)<br>    cross_tenant_replication_enabled  = optional(bool, true)<br>    delete_retention_policy           = optional(bool, true)<br>    versioning_enabled                = optional(bool, true)<br>    change_feed_enabled               = optional(bool, true)<br>    change_feed_days                  = optional(number, 35)<br>    create_with_rbac                  = optional(bool, false)<br>  }))</pre> | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| <a name="output_GITHUB_DEV_CLUSTER_FED"></a> [GITHUB\_DEV\_CLUSTER\_FED](#output\_GITHUB\_DEV\_CLUSTER\_FED) | n/a |

<!-- END_TF_DOCS -->
