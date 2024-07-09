terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.110.0"
    }
  }

  backend "azurerm" {
    tenant_id            = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
    subscription_id      = "16ede44b-1f74-40a5-b428-46cca9a5741b"
    resource_group_name  = "s941-tfstate"
    storage_account_name = "s941radixinfra"
    container_name       = "infrastructure"
    key                  = "dev/key-vault/terraform.tfstate"
    use_azuread_auth     = true # This enables RBAC instead of access keys
  }
}

provider "azurerm" {
  subscription_id = "16ede44b-1f74-40a5-b428-46cca9a5741b"
  features {
  }
}
