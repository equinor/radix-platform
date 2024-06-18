terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "<=3.100.0"
    }
    azapi = {
      source = "Azure/azapi"
    }
  }

  backend "azurerm" {
    tenant_id            = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
    subscription_id      = "16ede44b-1f74-40a5-b428-46cca9a5741b"
    resource_group_name  = "s941-tfstate"
    storage_account_name = "s941radixinfra"
    container_name       = "infrastructure"
    key                  = "acr/terraform.tfstate"
    use_azuread_auth     = true

  }
}
provider "azapi" {
  subscription_id = "16ede44b-1f74-40a5-b428-46cca9a5741b"
}

provider "azurerm" {
  storage_use_azuread = true
  subscription_id     = "16ede44b-1f74-40a5-b428-46cca9a5741b"
  features {
  }
}
