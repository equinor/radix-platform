terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

locals {
  mysql_flexible_server_firewall_rules = merge([for server_key, server_value in var.mysql_flexible_server : {
    for rule_key, rule_value in var.firewall_rules :
    "${server_key}-${rule_key}" => {
      start_ip_address    = rule_value.start_ip_address
      end_ip_address      = rule_value.end_ip_address
      server_name         = server_value.name
      resource_group_name = server_value.rg_name
    }
  }]...)

  mysql_server_firewall_rules = merge([for server_key, server_value in var.mysql_server : {
    for rule_key, rule_value in var.firewall_rules :
    "${server_key}-${rule_key}" => {
      start_ip_address    = rule_value.start_ip_address
      end_ip_address      = rule_value.end_ip_address
      server_name         = server_value.name
      resource_group_name = server_value.rg_name
    }
  }]...)

  all_sql_servers = merge(
    (var.mysql_flexible_server),
    (var.mysql_server),
  )
}

#######################################################################################
### Keyvault & Secrets
###

data "azurerm_key_vault" "keyvault" {
  for_each            = var.key_vault
  name                = each.value["name"]
  resource_group_name = each.value["rg_name"]
}

data "azurerm_key_vault_secret" "keyvault_secret" {
  for_each     = local.all_sql_servers
  name         = each.value["secret"]
  key_vault_id = data.azurerm_key_vault.keyvault[each.value["vault"]].id
}

#######################################################################################
### MYSQL Flexible Server
###

resource "azurerm_mysql_flexible_server" "mysql_flexible_server" {
  for_each               = var.mysql_flexible_server
  name                   = each.value["name"]
  administrator_password = data.azurerm_key_vault_secret.keyvault_secret[each.value["name"]].value
  resource_group_name    = each.value["rg_name"]
  location               = each.value["location"]
  administrator_login    = each.value["administrator_login"]
  backup_retention_days  = each.value["backup_retention_days"]
  sku_name               = each.value["sku_name"]
  version                = each.value["version"]
  zone                   = each.value["zone"]
}

resource "azurerm_mysql_flexible_server_firewall_rule" "main" {
  for_each            = local.mysql_flexible_server_firewall_rules
  name                = each.key
  start_ip_address    = each.value["start_ip_address"]
  end_ip_address      = each.value["end_ip_address"]
  server_name         = each.value["server_name"]
  resource_group_name = each.value["resource_group_name"]
  depends_on          = [azurerm_mysql_flexible_server.mysql_flexible_server]
}

#######################################################################################
### MYSQL Server
###

resource "azurerm_mysql_server" "mysql_server" {
  for_each                          = var.mysql_server
  name                              = each.value["name"]
  administrator_login_password      = data.azurerm_key_vault_secret.keyvault_secret[each.value["name"]].value
  resource_group_name               = each.value["rg_name"]
  location                          = each.value["location"]
  administrator_login               = each.value["administrator_login"]
  sku_name                          = each.value["sku_name"]
  version                           = each.value["version"]
  storage_mb                        = each.value["storage_mb"]
  auto_grow_enabled                 = true
  backup_retention_days             = 7
  geo_redundant_backup_enabled      = false
  infrastructure_encryption_enabled = false
  public_network_access_enabled     = true
  ssl_enforcement_enabled           = true
  ssl_minimal_tls_version_enforced  = each.value["ssl_minimal_tls_version_enforced"]
}

resource "azurerm_mysql_firewall_rule" "main" {
  for_each            = local.mysql_server_firewall_rules
  name                = each.key
  start_ip_address    = each.value["start_ip_address"]
  end_ip_address      = each.value["end_ip_address"]
  server_name         = each.value["server_name"]
  resource_group_name = each.value["resource_group_name"]
  depends_on          = [azurerm_mysql_server.mysql_server]
}
