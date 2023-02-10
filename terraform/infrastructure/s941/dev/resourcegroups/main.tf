terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}

resource "azurerm_resource_group" "resourcegroups" {
  for_each = var.resource_groups
  name     = each.value["name"]
  location = each.value["location"]
}
