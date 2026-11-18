module "loganalytics" {
  source              = "../../../modules/log-analytics"
  workspace_name      = "radix-logs-${module.config.environment}"
  resource_group_name = module.resourcegroup_common.data.name
  location            = module.resourcegroup_common.data.location
  retention_in_days   = 30
  ampls_enabled       = module.config.ampls_enabled
  ampls_scope_name    = module.base.ampls_name
  vnet_resource_group = module.resourcegroup_vnet.data.name
}

module "loganalytics_containers" {
  source              = "../../../modules/log-analytics"
  workspace_name      = "radix-container-logs-${module.config.environment}"
  resource_group_name = module.resourcegroup_common.data.name
  location            = module.resourcegroup_common.data.location
  retention_in_days   = 30
  ampls_enabled       = module.config.ampls_enabled
  ampls_scope_name    = module.base.ampls_name
  vnet_resource_group = module.resourcegroup_vnet.data.name
}