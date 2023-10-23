terraform {
  required_providers {
    azapi = {
      source = "Azure/azapi"
    }
  }
  backend "azurerm" {

  }
}


provider "azurerm" {
  features {}
}
