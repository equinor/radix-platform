terraform {
  required_providers {
    azapi = {
      source = "Azure/azapi"
    }
  }
  backend "azurerm" {}
}


provider "azapi" {
  subscription_id = var.AZ_SUBSCRIPTION_ID
}

provider "azurerm" {
  subscription_id = var.AZ_SUBSCRIPTION_ID

  features {}
}


variable "AZ_SUBSCRIPTION_ID" {
  type = string
}

variable "aks_cluster_resource_groups" {
  type = list(string)
}
variable "resource_groups" {
  type = map(object({
    name     = string                          # Mandatory
    location = optional(string, "northeurope") # Optional
  }))
  default = {}
}
