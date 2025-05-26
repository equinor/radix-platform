module "config" {
  source = "../../../modules/config"
}

data "azurerm_subscription" "current" {}

data "azuread_group" "radix" {
  display_name = "Radix"
}