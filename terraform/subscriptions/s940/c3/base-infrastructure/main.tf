module "config" {
  source = "../../../modules/config"
}

data "azurerm_subscription" "current" {}

data "azuread_group" "sql_admin" {
  display_name     = "Radix SQL server admin - c2"
  security_enabled = true
}

data "azuread_group" "radix" {
  display_name = "Radix Privileged Accounts"
}

data "azuread_group" "radix_az" {
  display_name = "AZAPPL ${module.config.subscription_shortname} - Owner"
}

data "azurerm_key_vault" "this" {
  name                = module.config.key_vault_name
  resource_group_name = module.config.common_resource_group
}