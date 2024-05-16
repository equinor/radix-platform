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
    client_id            = "f1e6bc52-9aa4-4ca7-a9ac-b7a19d8f0f86"
    resource_group_name  = "s941-tfstate"
    storage_account_name = "s941radixinfra"
    container_name       = "infrastructure"
    key                  = "playground/post-clusters/terraform.tfstate"
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
module "clusters" {
  source              = "../../../modules/active-clusters"
  resource_group_name = module.config.cluster_resource_group
  subscription        = module.config.subscription
}
