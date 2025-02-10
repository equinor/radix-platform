data "azurerm_subscription" "current" {}

data "azurerm_key_vault_secret" "this" {
  name         = "storageaccounts-ip-rule"
  key_vault_id = module.config.backend.ip_key_vault_id
}

# data "azapi_resource_action" "this" {
#   type                   = "Microsoft.KeyVault/vaults/secrets@2023-07-01"
#   resource_id            = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/common-dev/providers/Microsoft.KeyVault/vaults/radix-keyv-dev/secrets/storageaccounts-ip-rule"
#   action                 = "getSecret"
#   response_export_values = ["value"]
# }

# output "secret_value" {
#   value     = data.azapi_resource_action.this.output.value
#   sensitive = true
# }

module "keyvault" {
  source              = "../../../modules/key-vault"
  location            = module.config.location
  vault_name          = "radix-keyv-${module.config.environment}"
  resource_group_name = module.config.common_resource_group
  tenant_id           = data.azurerm_subscription.current.tenant_id
  vnet_resource_group = module.config.vnet_resource_group
  ip_rule             = "143.97.110.1"
}