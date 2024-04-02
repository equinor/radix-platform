resource "azurerm_resource_group" "resourcegroup" {
  name     = var.name
  location = var.location
  tags = {
    IaC = "terraform"
  }
}

resource "azurerm_role_assignment" "this" {
  for_each             = var.roleassignment ? { "${var.name}" : true } : {}
  scope                = azurerm_resource_group.resourcegroup.id
  role_definition_name = var.role_definition_name
  principal_id         = var.principal_id
}


