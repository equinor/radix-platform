module "config" {
  source = "../../../modules/config"
}

data "azurerm_log_analytics_workspace" "this" {
  name                = "radix-container-logs-dev"
  resource_group_name = "Logs-Dev"
}

module "log-api-mi" {
  source              = "../../../modules/userassignedidentity"
  name                = module.config.radix_log_api_mi_name
  resource_group_name = module.config.common_resource_group
  location            = module.config.location
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