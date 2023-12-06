terraform {
  # backend "azurerm" {}
}

provider "azurerm" {
  subscription_id = var.AZ_SUBSCRIPTION_ID

  features {}
}

resource "azurerm_resource_group" "resourcegroups" {
  for_each = var.resource_groups
  name     = each.value["name"]
  location = each.value["location"]
}
