resource "azurerm_federated_identity_credential" "this" {
  audience            = ["api://AzureADTokenExchange"]
  name                = var.name
  issuer              = var.issuer
  subject             = var.subject
  parent_id           = var.parent_id
  resource_group_name = var.resource_group_name
}