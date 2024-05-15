data "azurerm_kubernetes_cluster" "this" {
  for_each            = module.clusters.oidc_issuer_url
  name                = each.key
  resource_group_name = "clusters" #TODO with code below after cluster in new RG module.config.cluster_resource_group
}

resource "azurerm_role_assignment" "cluster" {
  for_each           = module.clusters.oidc_issuer_url
  scope              = data.azurerm_kubernetes_cluster.this[each.key].id
  role_definition_id = "/subscriptions/${module.config.subscription}${data.azurerm_role_definition.this.role_definition_id}"
  principal_id       = data.azuread_service_principal.this.object_id
}
