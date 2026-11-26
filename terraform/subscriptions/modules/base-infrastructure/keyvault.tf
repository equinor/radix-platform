data "azurerm_client_config" "current" {}

resource "azurerm_key_vault" "config" {
  name                          = var.keyvault_config_name
  location                      = var.location
  resource_group_name           = var.keyvault_config_resource_group_name
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

  depends_on = [module.common_resource_group]
}

resource "azurerm_network_security_perimeter_association" "config_key_vault" {
  name                                  = var.network_security_perimeter_name
  access_mode                           = "Enforced"
  network_security_perimeter_profile_id = module.network_security_perimeter.profile_id
  resource_id                           = azurerm_key_vault.config.id
}

module "keyvault" {
  source                   = "../key-vault"
  location                 = var.location
  vault_name               = var.keyvault_name
  resource_group_name      = var.keyvault_resource_group_name
  vnet_resource_group      = var.vnet_resource_group
  kv_secrets_user_id       = var.keyvault_secrets_user_id
  subscription_contributor = var.keyvault_subscription_contributor
  config_key_vault_id      = azurerm_key_vault.config.id
  config_key_vault_name    = azurerm_key_vault.config.name

  network_security_perimeter_profile_id = module.network_security_perimeter.profile_id
}
