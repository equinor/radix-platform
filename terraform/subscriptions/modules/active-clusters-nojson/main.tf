#Current Clusters

data "azapi_resource_list" "clusters" {
  type                   = "Microsoft.ContainerService/managedClusters@2023-09-01"
  parent_id              = "/subscriptions/${var.subscription}/resourcegroups/${var.resource_group_name}"
  response_export_values = ["*"]
}
output "ids" {
  value = { for k, v in data.azapi_resource_list.clusters.output.value : v.name => v.id }
}
output "oidc_issuer_url" {
  value = { for k, v in data.azapi_resource_list.clusters.output.value : v.name => v.properties.oidcIssuerProfile.issuerURL }
}
output "data" {
  value = { for k, v in data.azapi_resource_list.clusters.output.value : v.name => v }
}

#Current Vnets
data "azapi_resource_list" "vnets" {
  type                   = "Microsoft.Network/virtualNetworks@2023-09-01"
  parent_id              = "/subscriptions/${var.subscription}/resourcegroups/${var.resource_group_name}"
  response_export_values = ["*"]
}

output "vnets_url" {
  value = { for k, v in data.azapi_resource_list.vnets.output.value : v.name => v.id }
}

#Current NSGs

data "azapi_resource_list" "nsg" {
  type                   = "Microsoft.Network/networkSecurityGroups@2023-09-01"
  parent_id              = "/subscriptions/${var.subscription}/resourcegroups/${var.resource_group_name}"
  response_export_values = ["*"]
}

output "nsg" {
  value = { for k, v in data.azapi_resource_list.nsg.output.value : v.name => v.id }
}


