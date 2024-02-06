module "resourcegroup" {
  source = "../../../modules/resourcegroups"
  name     = "${var.resourse_group_name}-${local.external_outputs.common.data.enviroment}"
  location = local.external_outputs.common.data.location
}
data "azurerm_key_vault" "keyvault" {
  name = "radix-vault-dev"
  resource_group_name = "common"
}
data "azurerm_key_vault_secret" "keyvault_secrets" {
  name         = var.keyvault_dbadmin_secret_name
  key_vault_id = data.azurerm_key_vault.keyvault.id # local.external_outputs.keyvault.vault_id
}

# MS SQL Server
module "mssql-database" {
  source                        = "../../../modules/mssqldatabase"
  env                           = local.external_outputs.common.data.enviroment
  database_name                 = "sqldb-radix-cost-allocation"
  server_name                   = "sql-radix-cost-allocation-${local.external_outputs.common.data.enviroment}"
  admin_adgroup                 = var.admin-adgroup
  administrator_login           = "radix"
  administrator_password        = data.azurerm_key_vault_secret.keyvault_secrets.value
  rg_name                       = module.resourcegroup.data.name
  location                      = local.external_outputs.common.data.location
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
    test = {
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-cost-allocation:pull_request"
    }
  }
}

output "mi-client-id" {
  value = module.mssql-database.mi-admin
}
