resource "azurerm_resource_group_policy_assignment" "this" {
  name                 = var.policy_name
  display_name         = var.policy_name
  location             = var.location
  resource_group_id    = var.resource_group_id
  policy_definition_id = var.policy_definition_id
  identity {
    type         = "UserAssigned"
    identity_ids = [var.identity_ids]
  }

  parameters = jsonencode(
    {
      workspaceIdFromAssignment = {
        value = var.workspaceId

      }
    }
  )

}
