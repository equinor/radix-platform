module "config" {
  source = "../../../modules/config"
}

data "azurerm_subscription" "current" {}

data "azuread_group" "sql_admin" {
  display_name     = "Radix SQL server admin - ${module.config.environment}"
  security_enabled = true
}

data "azuread_group" "radix" {
  display_name = "Radix"
}

data "azurerm_key_vault" "this" {
  name                = module.config.key_vault_name
  resource_group_name = module.config.common_resource_group
}