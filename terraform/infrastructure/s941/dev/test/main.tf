terraform {
  backend "azurerm" {}
}

provider "azurerm" {
  features {}
}


resource "azurerm_resource_group" "test" {
  location = "northeurope"
  name     = "terraform-test-group"
}

