## Resource group
resource "azurerm_resource_group" "this" {
  name     = "${local.stack.name}"
  location = local.shared.location
}