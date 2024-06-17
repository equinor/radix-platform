data "azuread_group" "radix" {
  display_name = "Radix"
}

data "azuread_group" "radix-platform-developers" {
  display_name     = "Radix Platform Developers"
  security_enabled = true
}

data "azuread_group" "radix-platform-operators" {
  display_name     = "Radix Platform Operators"
  security_enabled = true
}
data "azurerm_subscription" "subscriptions" {
  for_each        = var.subscriptions
  subscription_id = each.value
}

resource "azurerm_role_assignment" "operator-roles" {
  for_each = var.operator-roles

  principal_id         = data.azuread_group.radix-platform-operators.id
  scope                = data.azurerm_subscription.subscriptions[each.value.subscription].id
  role_definition_name = each.value.role
}
resource "azurerm_role_assignment" "developer-roles" {
  for_each = var.developer-roles

  principal_id         = data.azuread_group.radix-platform-developers.id
  scope                = data.azurerm_subscription.subscriptions[each.value.subscription].id
  role_definition_name = each.value.role
}

resource "azuread_application_registration" "ar-radix-servicenow-proxy-client" {
  display_name                 = "ar-radix-servicenow-proxy-client"
  service_management_reference = "110327"

}

