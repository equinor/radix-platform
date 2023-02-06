terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

data "azurerm_mssql_server" "sqlserver" {
  for_each            = var.sql_server
  name                = each.value["name"]
  resource_group_name = each.value["rg_name"]
}

resource "azurerm_mssql_database" "mssql_database" {
  for_each          = var.sql_database
  name              = each.value["name"]
  server_id         = data.azurerm_mssql_server.sqlserver[each.value["server"]].id
  collation         = each.value["collation"]
  max_size_gb       = each.value["max_size_gb"]
  read_scale        = each.value["read_scale"]
  sku_name          = each.value["sku_name"]
  zone_redundant    = each.value["zone_redundant"]
  tags              = each.value["tags"]


}

