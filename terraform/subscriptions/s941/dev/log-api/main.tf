module "config" {
  source = "../../../modules/config"
}

data "azurerm_log_analytics_workspace" "this" {
  name = "radix-container-logs-dev"
  resource_group_name = "Logs-Dev"
}

data "azurerm_resource_group" "resourcegroup" {
  name     = module.config.common_resource_group
}

module "log-api-mi" {
  source              = "../../../modules/userassignedidentity"
  name                = module.config.radix_log_api_mi
  resource_group_name = data.azurerm_resource_group.resourcegroup.name
  location            = data.azurerm_resource_group.resourcegroup.location
  roleassignments = {
    role = {
      role     = "Log Analytics Reader"
      scope_id = data.azurerm_log_analytics_workspace.this.id
    }
  }
}

output "mi" {
  value = {
    client-id = module.log-api-mi.client-id,
    name      = module.log-api-mi.name
  }
}