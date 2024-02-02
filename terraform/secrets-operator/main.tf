resource "azurerm_user_assigned_identity" "userassignedidentity" {
  name                = "radix-id-external-secrets-operator-dev"
  location            = "northeurope"
  resource_group_name = "common-dev"
}

provider "azurerm" {
  subscription_id = "16ede44b-1f74-40a5-b428-46cca9a5741b"
  features {}
}