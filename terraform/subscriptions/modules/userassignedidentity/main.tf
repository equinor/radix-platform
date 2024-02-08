resource "azurerm_user_assigned_identity" "userassignedidentity" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
}

resource "azurerm_role_assignment" "this" {
  for_each             = var.roleassignments
  scope                = each.value.scope_id
  role_definition_name = each.value.role
  principal_id         = azurerm_user_assigned_identity.userassignedidentity.principal_id
}