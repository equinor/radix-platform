terraform {
  required_version = ">= 1.9"
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.1"
    }
    azapi = {
      source  = "Azure/azapi"
      version = "~>2.0"
    }
    jq = {
      source  = "massdriver-cloud/jq"
      version = "~>0.2.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes"
      version = ">=2.33.0"

    }
  }

  backend "azurerm" {
    tenant_id            = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
    subscription_id      = "16ede44b-1f74-40a5-b428-46cca9a5741b"
    resource_group_name  = "s941-tfstate"
    storage_account_name = "s941radixinfra"
    container_name       = "infrastructure"
    key                  = "dev/pre-clusters/terraform.tfstate"
    use_azuread_auth     = true # This enables RBAC instead of access keys
  }
}

provider "azurerm" {
  subscription_id = "16ede44b-1f74-40a5-b428-46cca9a5741b"
  features {
  }
}

module "config" {
  source = "../../../modules/config"
}

