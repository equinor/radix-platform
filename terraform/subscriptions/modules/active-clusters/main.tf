data "azapi_resource_list" "clusters" {
  type                   = "Microsoft.ContainerService/managedClusters@2023-09-01"
  parent_id              = "/subscriptions/${var.subscription}/resourcegroups/${var.resource_group_name}"
  response_export_values = ["*"]
}
output "ids" {
  value    = { for k, v in jsondecode(data.azapi_resource_list.clusters.output).value : v.name => v.id }
}
output "oidc_issuer_url" {
  value    = { for k, v in jsondecode(data.azapi_resource_list.clusters.output).value : v.name => v.properties.oidcIssuerProfile.issuerURL }
}
output "data" {
  value    = { for k, v in jsondecode(data.azapi_resource_list.clusters.output).value : v.name => v }
}
