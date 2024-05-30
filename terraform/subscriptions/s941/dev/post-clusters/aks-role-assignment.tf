data "azurerm_user_assigned_identity" "radix_id_aks_mi" {
  resource_group_name = module.config.common_resource_group
  name                = "radix-id-aks-${module.config.environment}"
}

resource "azurerm_role_assignment" "this" {
  for_each             = module.clusters.data
  scope                = "/subscriptions/${module.config.subscription}/resourceGroups/${each.value.properties.nodeResourceGroup}"
  role_definition_name = "Contributor"
  principal_id         = data.azurerm_user_assigned_identity.radix_id_aks_mi.principal_id
}

resource "azurerm_role_assignment" "vnet" {
  for_each             = module.clusters.data
  scope                = each.value.properties.agentPoolProfiles[0].vnetSubnetID
  role_definition_name = "Network Contributor"
  principal_id         = data.azurerm_user_assigned_identity.radix_id_aks_mi.principal_id
}