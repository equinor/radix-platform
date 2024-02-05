output "data" {
  value = local.outputs
}

output "policy_aks_cluster_id" {
  value = resource.azurerm_policy_definition.policy_aks_cluster.id
}