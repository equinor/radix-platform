# data "azurerm_resource_group" "monitoring" { # Defined in Global
#   name = "monitoring"
# }

# data "azurerm_resource_group" "networkwatcher" { # Defined in Global
#   name = "NetworkWatcherRG"
# }

module "resourcegroup_common" {
  source   = "../../modules/resourcegroups"
  name     = var.common_resource_group
  location = var.location
}

module "resourcegroup_clusters" {
  source   = "../../modules/resourcegroups"
  name     = var.cluster_resource_group
  location = var.location
}

module "resourcegroup_logs" {
  source   = "../../modules/resourcegroups"
  name     = "logs-${var.environment}"
  location = var.location
}


module "resourcegroup_cost_allocation" {
  source   = "../../modules/resourcegroups"
  name     = "cost-allocation-${var.environment}"
  location = var.location
}

# module "resourcegroup_vulnerability_scan" {
#   source   = "../../modules/resourcegroups"
#   name     = "vulnerability-scan-${var.environment}"
#   location = var.location
# }

module "resourcegroup_vnet" {
  source   = "../../modules/resourcegroups"
  name     = var.vnet_resource_group
  location = var.location
}

# data "azurerm_resource_group" "logs" { #TODO Needed by gitrunner
#   name = "Logs-${var.location}"
# }

output "az_resource_group_clusters" {
  value = module.resourcegroup_clusters.data.name
}

output "az_resource_group_common" {
  value = var.common_resource_group
}
