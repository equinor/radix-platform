terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

data "azurerm_key_vault" "keyvault" {
  for_each            = var.key_vault
  name                = each.value["name"]
  resource_group_name = each.value["rg_name"]
}

data "azurerm_key_vault_secret" "keyvault_secret" {
  for_each     = var.key_secrets
  name         = each.value["name"]
  key_vault_id = data.azurerm_key_vault.keyvault[each.value["vault"]].id
}

data "azuread_group" "developers" {
  display_name     = "Radix Platform Developers"
  security_enabled = true
}

resource "azurerm_mssql_server" "sqlserver" {
  for_each                     = var.sql_server
  administrator_login          = each.value["administrator_login"]
  administrator_login_password = data.azurerm_key_vault_secret.keyvault_secret[each.value["name"]].value
  location                     = each.value["location"]
  minimum_tls_version          = each.value["minimum_tls_version"]
  name                         = each.value["name"]
  resource_group_name          = each.value["rg_name"]
  tags                         = each.value["tags"]
  version                      = each.value["version"]

  dynamic "azuread_administrator" {
    for_each = each.value["azuread_administrator"] != null ? [each.value["azuread_administrator"]] : []

    content {
      login_username              = data.azuread_group.developers.display_name
      object_id                   = data.azuread_group.developers.id
      azuread_authentication_only = azuread_administrator.value["azuread_authentication_only"]
    }
  }

  dynamic "identity" {
    for_each = each.value["identity"] ? [1] : []
    content {
      identity_ids = []
      type         = "SystemAssigned"
    }
  }
}

resource "azurerm_mssql_database" "mssql_database" {
  for_each       = var.sql_database
  name           = each.value["name"]
  server_id      = azurerm_mssql_server.sqlserver[each.value["server"]].id
  collation      = each.value["collation"]
  max_size_gb    = each.value["max_size_gb"]
  read_scale     = each.value["read_scale"]
  sku_name       = each.value["sku_name"]
  zone_redundant = each.value["zone_redundant"]
  tags           = each.value["tags"]
  depends_on     = [azurerm_mssql_server.sqlserver]
}
