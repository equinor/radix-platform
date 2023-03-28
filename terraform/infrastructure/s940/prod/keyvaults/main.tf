terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

data "azuread_service_principal" "SP_GITHUB_ACTION_CLUSTER" {
  application_id = var.SP_GITHUB_ACTION_CLUSTER_CLIENT_ID
}

data "azurerm_key_vault" "KV_RADIX_VAULT" {
  name                = var.KV_RADIX_VAULT
  resource_group_name = var.AZ_RESOURCE_GROUP_COMMON
}

resource "azurerm_key_vault_access_policy" "AP_KV_SP_GITHUB_ACTION_CLUSTER" {
  key_vault_id = data.azurerm_key_vault.KV_RADIX_VAULT.id
  object_id    = data.azuread_service_principal.SP_GITHUB_ACTION_CLUSTER.object_id
  tenant_id    = var.AZ_TENANT_ID

  secret_permissions = ["Get", "List", "Set"]
}