# MS SQL Server
module "mssql-database" {
  source                        = "../../../modules/mssqldatabase"
  env                           = module.config.environment
  database_name                 = "sqldb-radix-cost-allocation"
  server_name                   = "sql-radix-cost-allocation-${module.config.environment}"
  managed_identity_admin_name   = "radix-id-cost-allocation-admin-${module.config.environment}"
  audit_storageaccount_name     = module.config.log_storageaccount_name
  admin_adgroup                 = data.azuread_group.sql_admin.display_name
  azuread_authentication_only   = true
  administrator_login           = "radix"
  rg_name                       = module.resourcegroup_cost_allocation.data.name
  vnet_resource_group           = module.config.vnet_resource_group
  common_resource_group         = module.config.common_resource_group
  location                      = module.config.location
  public_network_access_enabled = true
  sku_name                      = "S3"
  zone_redundant                = false
  subscription                  = module.config.subscription
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


# data "azurerm_container_registry" "acr" {
#   name                = "radixprod" # TODO: Fix to platform
#   resource_group_name = "common"    # TODO: Fix module.config.common_resource_group
# }

module "mi-writer" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-cost-allocation-writer-${module.config.environment}"
  resource_group_name = module.resourcegroup_cost_allocation.data.name
  location            = module.resourcegroup_cost_allocation.data.location
}

module "mi-reader" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-cost-allocation-reader-${module.config.environment}"
  resource_group_name = module.resourcegroup_cost_allocation.data.name
  location            = module.resourcegroup_cost_allocation.data.location
}

output "mi-client-id" {
  value = module.mssql-database.mi-admin
}
output "github-buildpush-workflow" {
  value = {
    client-id = module.github-workload-id.client-id
    name      = module.github-workload-id.name
  }
}
output "mi-writer" {
  value = {
    client-id = module.mi-writer.client-id,
    name      = module.mi-writer.name
  }
}
output "mi-reader" {
  value = {
    client-id = module.mi-reader.client-id,
    name      = module.mi-reader.name
  }
}