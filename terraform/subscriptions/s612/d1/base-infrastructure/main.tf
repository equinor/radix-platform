module "config" {
  source = "../../../modules/config"
}

module "radix_base" {
  source = "../../../modules/radix_base"
}

data "azurerm_subscription" "current" {}

data "azuread_group" "radix" {
  display_name = "Radix"
}