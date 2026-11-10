resource "azurerm_key_vault" "config" {
  name                          = "radix-config-${module.config.environment}"
  location                      = module.config.location
  resource_group_name           = module.config.common_resource_group
  tenant_id                     = data.azurerm_client_config.current.tenant_id
  public_network_access_enabled = false
  soft_delete_retention_days    = 30
  purge_protection_enabled      = true
  tags = {
    IaC = "terraform"
  }
  network_acls {
    bypass         = "AzureServices"
    default_action = "Deny"
    ip_rules       = []
  }
  sku_name = "standard"
}

module "keyvault" {
  source                   = "../../../modules/key-vault"
  location                 = module.config.location
  vault_name               = "radix-keyv-${module.config.environment}"
  resource_group_name      = module.config.common_resource_group
  vnet_resource_group      = module.config.vnet_resource_group
  subscription_contributor = module.config.subscription_contributor
  config_key_vault_id      = azurerm_key_vault.config.id
  config_key_vault_name    = azurerm_key_vault.config.name
}

output "keyvault_name" {
  value = module.keyvault.vault_name
}

output "keyvault_config_name" {
  value = module.keyvault.config_keyvault_name
}