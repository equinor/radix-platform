# MS SQL Server
# module "mssql-database" {
#   source                        = "../../modules/mssqldatabase"
#   env                           = var.environment
#   database_name                 = "sqldb-radix-cost-allocation"
#   server_name                   = "sql-radix-cost-allocation-${var.environment}"
#   managed_identity_admin_name   = "radix-id-cost-allocation-admin-${var.environment}"
#   audit_storageaccount_name     = module.config.log_storageaccount_name
#   admin_adgroup                 = data.azuread_group.sql_admin.display_name
#   azuread_authentication_only   = true
#   administrator_login           = "radix"
#   rg_name                       = module.resourcegroup_cost_allocation.data.name
#   vnet_resource_group           = var.vnet_resource_group
#   common_resource_group         = var.common_resource_group
#   location                      = var.location
#   public_network_access_enabled = true
#   zone_redundant                = false
#   subscription                  = module.config.subscription
#   tags = {
#     displayName = "SqlServer"
#   }
#   database_tags = {
#     displayName = "Database"
#   }

#   admin_federated_credentials = {
#     github-master = {
#       issuer  = "https://token.actions.githubusercontent.com"
#       subject = "repo:equinor/radix-cost-allocation:ref:refs/heads/master"
#     }
#     github-release = {
#       issuer  = "https://token.actions.githubusercontent.com"
#       subject = "repo:equinor/radix-cost-allocation:ref:refs/heads/release"
#     }
#   }
# }

# module "github-workload-id" {
#   source              = "../../modules/userassignedidentity"
#   name                = "radix-id-cost-allocation-github-${var.environment}"
#   resource_group_name = module.resourcegroup_cost_allocation.data.name
#   location            = module.resourcegroup_cost_allocation.data.location
#   roleassignments = {
#     contributor = {
#       role     = "Contributor" # Needed to open firewall
#       scope_id = module.acr.azurerm_container_registry_id
#     },
#   }
#   federated_credentials = {
#     github-main = {
#       name    = "gh-radix-cost-allocation-acr-main-${var.environment}"
#       issuer  = "https://token.actions.githubusercontent.com"
#       subject = "repo:equinor/radix-cost-allocation:ref:refs/heads/release"
#     }
#   }
# }

module "mi-writer" {
  source              = "../../modules/userassignedidentity"
  name                = "radix-id-cost-allocation-writer-${var.environment}"
  resource_group_name = module.resourcegroup_cost_allocation.data.name
  location            = module.resourcegroup_cost_allocation.data.location
}

module "mi-reader" {
  source              = "../../modules/userassignedidentity"
  name                = "radix-id-cost-allocation-reader-${var.environment}"
  resource_group_name = module.resourcegroup_cost_allocation.data.name
  location            = module.resourcegroup_cost_allocation.data.location
}

# output "mi-client-id" {
#   value = module.mssql-database.mi-admin
# }
# output "github-buildpush-workflow" {
#   value = {
#     client-id = module.github-workload-id.client-id
#     name      = module.github-workload-id.name
#   }
# }
# output "mi-writer" {
#   value = {
#     client-id = module.mi-writer.client-id,
#     name      = module.mi-writer.name
#   }
# }
# output "mi-reader" {
#   value = {
#     client-id = module.mi-reader.client-id,
#     name      = module.mi-reader.name
#   }
# }
