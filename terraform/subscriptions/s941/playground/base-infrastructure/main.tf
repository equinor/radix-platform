module "config" {
  source = "../../../modules/config"
}

data "azurerm_subscription" "current" {}

data "azuread_group" "sql_admin" {
  display_name     = "Radix SQL server admin - ${module.config.environment}"
  security_enabled = true
}

data "azurerm_key_vault_secret" "this" {
  name         = "storageaccounts-ip-rule"
  key_vault_id = module.config.backend.ip_key_vault_id
}

data "azurerm_key_vault_secret" "radixowners" {
  name         = "radixowners"
  key_vault_id = module.config.backend.ip_key_vault_id
}