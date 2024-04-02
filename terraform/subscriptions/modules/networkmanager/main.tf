resource "azurerm_network_manager" "networkmanager" {
  name                = "${var.subscription_shortname}-ANVM"
  location            = var.location
  resource_group_name = var.resource_group
  scope_accesses      = ["Connectivity"]
  description         = "${var.subscription_shortname}-Azure Network Mananger - ${var.location}"
  tags = {
    IaC = "terraform"
  }

  scope {
    subscription_ids = ["/subscriptions/${var.subscription}"]
  }
}
