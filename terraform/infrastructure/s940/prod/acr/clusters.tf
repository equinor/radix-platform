data "azapi_resource_list" "clusters" {
  type                   = "Microsoft.ContainerService/managedClusters@2023-09-01"
  parent_id              = "/subscriptions/${var.AZ_SUBSCRIPTION_ID}/resourcegroups/${var.AZ_RESOURCE_GROUP_CLUSTERS}"
  response_export_values = ["*"]
}

data "azurerm_kubernetes_cluster" "k8s" {
  for_each = {for cluster in jsondecode(data.azapi_resource_list.clusters.output).value : cluster.name => cluster}
  
  name                = each.value.name
  resource_group_name = var.AZ_RESOURCE_GROUP_CLUSTERS
}

locals {
  clusterEnvironment = {
    for cluster in data.azurerm_kubernetes_cluster.k8s : cluster.name =>
    startswith( lower(cluster.name), "weekly-" ) ? "dev" :
    startswith(lower( cluster.name), "playground-") ? "playground" :
    startswith(lower( cluster.name), "eu-") ? "prod" :
    startswith(lower( cluster.name), "c2-") ? "c2" : "unknown"
  }
}

output "clusters" {
  value = local.clusterEnvironment
}
