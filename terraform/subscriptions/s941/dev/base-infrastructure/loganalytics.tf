module "loganalytics" {
  source              = "../../../modules/log-analytics"
  workspace_name      = "radix-logs-${module.config.environment}"
  resource_group_name = module.resourcegroup_common.data.name
  location            = module.resourcegroup_common.data.location
  retention_in_days   = 30
  ampls_enabled       = module.config.ampls_enabled
  ampls_scope_name    = module.base.ampls_name
  ampls_resource_group = module.config.common_resource_group
}

module "loganalytics_containers" {
  source              = "../../../modules/log-analytics"
  workspace_name      = "radix-container-logs-${module.config.environment}"
  resource_group_name = module.resourcegroup_common.data.name
  location            = module.resourcegroup_common.data.location
  retention_in_days   = 30
  ampls_enabled       = module.config.ampls_enabled
  ampls_scope_name    = module.base.ampls_name
  ampls_resource_group = module.config.common_resource_group
}