data "azapi_resource_list" "clusters" {
  for_each = toset(var.aks_clouster_resource_groups)

  type                   = "Microsoft.ContainerService/managedClusters@2023-09-01"
  parent_id              = "/subscriptions/${var.AZ_SUBSCRIPTION_ID}/resourcegroups/${var.resource_groups[each.value].name}"
  response_export_values = ["*"]
}

locals {
  k8s_resources = flatten([
    for key, resource in data.azapi_resource_list.clusters :[
      for cluster in jsondecode(resource.output).value :
      {
        id : cluster.id,
        name : cluster.name,
        rgName : key,
        location : cluster.location
      }
    ]
  ])
}

data "azurerm_kubernetes_cluster" "k8s" {
  for_each = {for cluster in local.k8s_resources : cluster.name => cluster}

  name                = each.value.name
  resource_group_name = each.value.rgName
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
