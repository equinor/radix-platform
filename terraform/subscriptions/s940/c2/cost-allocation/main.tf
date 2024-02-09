module "config" {
  source = "../../../modules/config"
}

module "resourcegroup" {
  source   = "../../../modules/resourcegroups"
  name     = "cost-allocation-${module.config.environment}"
  location = module.config.location
}
data "azurerm_key_vault" "keyvault" {
  name                = module.config.key_vault_name
  resource_group_name = module.config.common_resource_group
}
data "azurerm_key_vault_secret" "keyvault_secrets" {
  name         = var.keyvault_dbadmin_secret_name
  key_vault_id = data.azurerm_key_vault.keyvault.id # local.external_outputs.keyvault.vault_id
}

# MS SQL Server
module "mssql-database" {
  source                        = "../../../modules/mssqldatabase"
  env                           = module.config.environment
  managed_identity_admin_name   = "radix-id-cost-allocation-admin-c2"
  database_name                 = "sqldb-radix-cost-allocation"
  server_name                   = "sql-radix-cost-allocation-${module.config.environment}-prod" # https://github.com/equinor/radix-platform/issues/1190
  admin_adgroup                 = var.admin-adgroup
  administrator_login           = "radix"
  administrator_password        = data.azurerm_key_vault_secret.keyvault_secrets.value
  rg_name                       = module.resourcegroup.data.name
  vnet_resource_group           = module.config.vnet_resource_group
  location                      = module.config.location
  public_network_access_enabled = true
  zone_redundant                = false
  tags = {
    displayName = "SqlServer"
  }
  database_tags = {
    displayName = "Database"
  }

  admin_federated_credentials = {
    github-master = {
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-cost-allocation:ref:refs/heads/master"
    }
    github-release = {
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-cost-allocation:ref:refs/heads/release"
    }
  }
}

output "mi-client-id" {
  value = module.mssql-database.mi-admin
}
