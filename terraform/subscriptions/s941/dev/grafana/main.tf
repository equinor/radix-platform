module "config" {
  source = "../../../modules/config"
}


data "azuread_group" "mssql-developers" {
  display_name     = "Radix SQL server admin - dev"
  security_enabled = true
}

data "azurerm_key_vault" "this" {
  name                = module.config.key_vault_name
  resource_group_name = module.config.common_resource_group
}

data "azurerm_key_vault_secret" "radixadmin" {
  name         = "mysql-grafana-dev-admin-password"
  key_vault_id = data.azurerm_key_vault.this.id
}

resource "azurerm_mysql_flexible_server" "this" {
  location               = module.config.location
  name                   = "${module.config.subscription_shortname}-radix-grafana-${module.config.environment}"
  resource_group_name    = "monitoring"
  zone                   = "2"
  sku_name               = "B_Standard_B1ms"
  administrator_login    = "radixadmin"
  administrator_password = data.azurerm_key_vault_secret.radixadmin.value

  tags = {
    IaC = "terraform"
  }

  identity {
    identity_ids = [module.grafana-mi-server.id]
    type = "UserAssigned"
  }
}

resource "azurerm_mysql_flexible_database" "grafana" {
  resource_group_name = azurerm_mysql_flexible_server.this.resource_group_name

  name        = "grafana"
  charset     = "latin1"
  collation   = "latin1_swedish_ci"
  server_name = azurerm_mysql_flexible_server.this.name
}

# This MI must not be deleted, has been given Directory Reader role by Equnior AAD Team!
module "grafana-mi-server" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-grafana-server-${module.config.environment}"
  resource_group_name = "monitoring"
  location            = module.config.location
}

module "grafana-mi-admin" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-grafana-admin-${module.config.environment}"
  resource_group_name = "monitoring"
  location            = module.config.location
}

data "azuread_group" "mysql-admin" {
  display_name = var.admin-group-name
}
# resource "azuread_group_member" "this" {
#   group_object_id  = data.azuread_group.mssql-developers.object_id
#   member_object_id = module.grafana-mi-admin.principal_id
# }

output "mi-admin" {
  value = {
    client-id = module.grafana-mi-admin.client-id,
    name      = module.grafana-mi-admin.name
  }
}

output "mi-server" {
  value = {
    client-id = module.grafana-mi-server.client-id,
    name      = module.grafana-mi-server.name
  }
}
