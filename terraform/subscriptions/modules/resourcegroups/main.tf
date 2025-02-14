resource "azurerm_resource_group" "resourcegroup" {
  name     = var.name
  location = var.location
  tags = {
    IaC = "terraform"
  }
}

output "data" {
  description = "resourcegroup"
  value       = azurerm_resource_group.resourcegroup
}