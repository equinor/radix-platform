terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.110.0"
    }
  }

  backend "azurerm" {
    tenant_id            = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
    subscription_id      = "ded7ca41-37c8-4085-862f-b11d21ab341a"
    resource_group_name  = "s940-tfstate"
    storage_account_name = "s940radixinfra"
    container_name       = "infrastructure"
    key                  = "prod/globals/terraform.tfstate"
    use_azuread_auth     = true # This enables RBAC instead of access keys
  }
}

provider "azurerm" {
  subscription_id     = "ded7ca41-37c8-4085-862f-b11d21ab341a"
  storage_use_azuread = true
  features {}
}

provider "azuread" {
  tenant_id = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
}

module "config" {
  source = "../../../modules/config"
}