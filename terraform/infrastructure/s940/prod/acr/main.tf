terraform {
  required_providers {
    azapi = {
      source = "Azure/azapi"
    }
  }
  backend "azurerm" {

  }
}

provider "azapi" {
  subscription_id = var.AZ_SUBSCRIPTION_ID
}

provider "azurerm" {
  subscription_id = var.AZ_SUBSCRIPTION_ID

  features {}
}
