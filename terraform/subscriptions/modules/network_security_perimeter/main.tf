resource "azurerm_network_security_perimeter" "this" {
  name                = var.network_security_perimeter_name
  resource_group_name = var.resource_group_name
  location            = var.location
  tags = {
    IaC = "terraform"
  }
}

resource "azurerm_network_security_perimeter_profile" "this" {
  name                          = var.profile_name
  network_security_perimeter_id = azurerm_network_security_perimeter.this.id
}

resource "azurerm_network_security_perimeter_association" "this" {
  for_each = var.associations

  name                                  = each.value.name
  access_mode                           = "Enforced"
  network_security_perimeter_profile_id = azurerm_network_security_perimeter_profile.this.id
  resource_id                           = each.value.resource_id
}

output "profile_id" {
  description = "ID of the network security perimeter profile."
  value       = azurerm_network_security_perimeter_profile.this.id
}