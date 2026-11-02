resource "azurerm_role_definition" "this" {
  name        = var.name
  scope       = var.scope
  description = var.description

  permissions {
    actions          = var.actions
    not_actions      = var.not_actions
    data_actions     = var.data_actions
    not_data_actions = var.not_data_actions
  }

  assignable_scopes = var.assignable_scopes
}