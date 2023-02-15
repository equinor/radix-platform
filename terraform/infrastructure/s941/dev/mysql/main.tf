terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

# locals {
#   WHITELIST_IPS = jsondecode(textdecodebase64("${data.azurerm_key_vault_secret.whitelist_ips.value}", "UTF-8"))
# }

locals {
  #sql_servers = values(var.mysql_server)[*].name
 
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

# resource "azurerm_virtual_network" "example" {
#   name                = "example-vn"
#   location            = azurerm_resource_group.example.location
#   resource_group_name = azurerm_resource_group.example.name
#   address_space       = ["10.0.0.0/16"]
# }

# resource "azurerm_subnet" "example" {
#   name                 = "example-sn"
#   resource_group_name  = azurerm_resource_group.example.name
#   virtual_network_name = azurerm_virtual_network.example.name
#   address_prefixes     = ["10.0.2.0/24"]
#   service_endpoints    = ["Microsoft.Storage"]
#   delegation {
#     name = "fs"
#     service_delegation {
#       name = "Microsoft.DBforMySQL/flexibleServers"
#       actions = [
#         "Microsoft.Network/virtualNetworks/subnets/join/action",
#       ]
#     }
#   }
# }

# resource "azurerm_private_dns_zone" "example" {
#   name                = "example.mysql.database.azure.com"
#   resource_group_name = azurerm_resource_group.example.name
# }

# resource "azurerm_private_dns_zone_virtual_network_link" "example" {
#   name                  = "exampleVnetZone.com"
#   private_dns_zone_name = azurerm_private_dns_zone.example.name
#   virtual_network_id    = azurerm_virtual_network.example.id
#   resource_group_name   = azurerm_resource_group.example.name
# }

resource "azurerm_mysql_flexible_server" "mysql_flexible_server" {
  for_each                = var.mysql_flexible_server
  administrator_password  = data.azurerm_key_vault_secret.keyvault_secret[each.value["name"]].value
  name                    = each.value["name"]
  resource_group_name     = each.value["rg_name"]
  location                = each.value["location"]
  administrator_login     = each.value["administrator_login"]
  backup_retention_days   = each.value["backup_retention_days"]
  sku_name                = each.value["sku_name"]
  version                 = each.value["version"]
  zone                    = each.value["zone"]
  
  
  # delegated_subnet_id     = each.value["delegated_subnet_id"]
  # private_dns_zone_id     = each.value["private_dns_zone_id"]
  

  #depends_on = [azurerm_private_dns_zone_virtual_network_link.example]
}

resource "azurerm_mysql_flexible_server_firewall_rule" "main" {
  for_each            = var.firewall_rules != null ? { for key, values in var.firewall_rules : key => values if values != null } : {}
  name                = format("%s", each.key)
  start_ip_address    = each.value["start_ip_address"]
  end_ip_address      = each.value["end_ip_address"]
  server_name         = "s941-radix-grafana-dev"
  resource_group_name = "monitoring"
  depends_on = [azurerm_mysql_flexible_server.mysql_flexible_server]
  
}

# resource "azurerm_resource_group" "example" {
#   name     = "example-resources"
#   location = "West Europe"
# }

resource "azurerm_mysql_server" "mysql_server" {
  for_each                     = var.mysql_server
  name                         = each.value["name"]
  location                     = each.value["location"]
  resource_group_name          = each.value["rg_name"]
  administrator_login          = each.value["administrator_login"]
  administrator_login_password = data.azurerm_key_vault_secret.keyvault_secret[each.value["name"]].value

  sku_name   = each.value["sku_name"]
  storage_mb = each.value["storage_mb"]
  version    = each.value["version"]

  auto_grow_enabled                 = true
  backup_retention_days             = 7
  geo_redundant_backup_enabled      = false
  infrastructure_encryption_enabled = false
  public_network_access_enabled     = true
  ssl_enforcement_enabled           = true
  ssl_minimal_tls_version_enforced  = each.value["ssl_minimal_tls_version_enforced"]
}

# output "mysql_server" {
#   value = var.firewall_rules
# }

resource "azurerm_mysql_firewall_rule" "main" {
  for_each            = var.firewall_rules != null ? { for key, values in var.firewall_rules : key => values if values != null } : {}
  name                = format("%s", each.key)
  start_ip_address    = each.value["start_ip_address"]
  end_ip_address      = each.value["end_ip_address"]
  server_name         = "mysql-radix-grafana-dev"
  resource_group_name = "monitoring"
  depends_on = [azurerm_mysql_server.mysql_server]
  #server_name         = each.value.flatten_mysql_server
  #resource_group_name = each.value.flatten_mysql_rg
     
  #server_name          = {for_each = each.value[local.sql_servers.value]}
  # dynamic "server_name" {
  #   for_each = var.mysql_server
  #   content {
  #     server_name = each.value["name"]
  #   }
  # }
}

  # resource_group_name = "monitoring" # local.resource_group_name
  # #resource_group_name = {for_each = values(var.mysql_server)[*].rg_name}
  # #server_name         = "mysql-radix-grafana-dev" # azurerm_mysql_server.main.name
  # #server_name          = {for_each = values(var.mysql_server)[*].name}
  # server_name         = azurerm_mysql_server.mysql_server[each.key]

#}


