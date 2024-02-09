data "azuread_group" "admin" {
  display_name     = var.admin_adgroup
  security_enabled = true
}

resource "azurerm_user_assigned_identity" "admin" {
  name                = var.managed_identity_admin_name
  location            = var.location
  resource_group_name = var.rg_name
}

resource "azuread_group_member" "admin" {
  group_object_id  = data.azuread_group.admin.id
  member_object_id = azurerm_user_assigned_identity.admin.principal_id
}

resource "azurerm_federated_identity_credential" "admin-fedcred" {
  for_each = var.admin_federated_credentials

  audience            = ["api://AzureADTokenExchange"]
  issuer              = each.value.issuer
  name                = "gh-radix-${var.server_name}-admin-${each.key}"
  parent_id           = azurerm_user_assigned_identity.admin.id
  resource_group_name = var.rg_name
  subject             = each.value.subject
}
