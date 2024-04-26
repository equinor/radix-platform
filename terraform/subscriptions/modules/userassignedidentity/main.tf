resource "azurerm_user_assigned_identity" "userassignedidentity" {
  name                = var.name
  location            = var.location
  resource_group_name = var.resource_group_name
  tags = {
    IaC = "terraform"
  }
}

resource "azurerm_role_assignment" "this" {
  for_each             = var.roleassignments
  scope                = each.value.scope_id
  role_definition_name = each.value.role
  principal_id         = azurerm_user_assigned_identity.userassignedidentity.principal_id
}

resource "azurerm_federated_identity_credential" "this" {
  for_each = var.federated_credentials

  audience            = ["api://AzureADTokenExchange"]
  issuer              = each.value.issuer
  name                = each.value.name
  parent_id           = azurerm_user_assigned_identity.userassignedidentity.id
  resource_group_name = var.resource_group_name
  subject             = each.value.subject
}
