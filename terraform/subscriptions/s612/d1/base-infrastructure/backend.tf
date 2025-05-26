terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.110.0"
    }
    azuread = {
      source  = "hashicorp/azuread"
      version = "< 3.0.0"
    }
  }

  backend "azurerm" {
    tenant_id            = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0" # template
    subscription_id      = "939950ec-da7e-4349-8b8d-77d9c278af04" # template
    resource_group_name  = "s612-tfstate"                         # template
    storage_account_name = "s612radixinfra"                       # template
    container_name       = "tfstate"
    key                  = "d1/base/terraform.tfstate" # template
    use_azuread_auth     = true                        # This enables RBAC instead of access keys
  }
}

provider "azurerm" {
  subscription_id     = "939950ec-da7e-4349-8b8d-77d9c278af04" # template
  storage_use_azuread = true                                   # This enables RBAC instead of access keys
  features {}
}

