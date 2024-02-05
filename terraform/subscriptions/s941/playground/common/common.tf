locals {
  outputs = {
    location       = "northeurope"
    resource_group = "common"
    enviroment     = "playground"
    enviroment_L   = "playground"
    enviroment_S   = "playground"
  }
}

output "mi_id" {
  value = module.mi.data.id
}

output "workspace_id" {
  value = module.loganalytics.data.workspace_id
}