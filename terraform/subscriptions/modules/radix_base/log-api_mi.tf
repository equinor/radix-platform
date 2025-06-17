module "log-api-mi" {
  source              = "../../modules/userassignedidentity"
  name                = "radix-id-log-api-${var.environment}"
  resource_group_name = var.common_resource_group
  location            = var.location
  roleassignments = {
    role = {
      role     = "Log Analytics Reader"
      scope_id = module.loganalytics_containers.workspace_id
    }
  }
}

output "mi" {
  value = {
    client-id = module.log-api-mi.client-id,
    name      = module.log-api-mi.name
  }
}