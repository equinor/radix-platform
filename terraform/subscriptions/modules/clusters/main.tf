data "azapi_resource_list" "clusters" {
  for_each = toset(var.resource_groups)

  type                   = "Microsoft.ContainerService/managedClusters@2023-09-01"
  parent_id              = "/subscriptions/${var.subscription}/resourcegroups/${each.value}"
  response_export_values = ["*"]
}


#data "azurerm_kubernetes_cluster" "k8s" {
#  for_each = { for cluster in local.k8s_resources : cluster.name => cluster }
#
#  name                = each.value.name
#  resource_group_name = each.value.rgName
#}
#
#locals {
#  clusterEnvironment = {
#    for cluster in data.azurerm_kubernetes_cluster.k8s : cluster.name =>
#    startswith(lower(cluster.name), "weekly-") ? "dev" :
#    startswith(lower(cluster.name), "playground-") ? "playground" :
#    startswith(lower(cluster.name), "eu-") ? "prod" :
#    startswith(lower(cluster.name), "ext-mon-") ? "extmon" :
#    startswith(lower(cluster.name), "c2-") ? "c2" : "unknown"
#  }
#}

