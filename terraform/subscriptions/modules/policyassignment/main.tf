resource "azurerm_subscription_policy_assignment" "assignment" {
  display_name         = "Kubernetes-vnets-in-${var.enviroment}"
  name                 = "Kubernetes-vnets-in-${var.enviroment}"
  location             = var.location
  policy_definition_id = var.policy_id
  subscription_id      = var.subscription
  parameters           = jsonencode({})
  identity {
    identity_ids = []
    type         = "SystemAssigned"
  }

}
