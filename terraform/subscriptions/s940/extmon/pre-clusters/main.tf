data "azurerm_key_vault" "this" {
  name                = module.config.key_vault_name
  resource_group_name = module.config.common_resource_group
}

data "azurerm_key_vault_secret" "this" {
  name         = "radix-clusters"
  key_vault_id = data.azurerm_key_vault.this.id
}

data "azurerm_storage_account" "this" {
  name                = "radixlog${module.config.environment}"
  resource_group_name = module.config.common_resource_group
}
