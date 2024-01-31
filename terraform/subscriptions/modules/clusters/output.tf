#
#output "clusters" {
#  description = "Cluster Resourcess"
#  value = azurerm_kubernetes_cluster.k8s
#}
#
#output "clusterEnvironment" {
#  description = "Cluster Environements"
#  value = local.clusterEnvironment
#}

locals {
  k8s_resources = flatten([
    for key, resource in data.azapi_resource_list.clusters : [
      for cluster in jsondecode(resource.output).value :
      {
        id : cluster.id,
        name : cluster.name,
        resource_group : key,
        location : cluster.location
      }
    ]
  ])
}

output "k8s_resources" {
  description = "Clusters"
  value = local.k8s_resources
}
