terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "<=3.69.0"
    }
    azapi = {
      source = "Azure/azapi"
    }
  }

  backend "azurerm" {
    tenant_id       = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
    subscription_id = "ded7ca41-37c8-4085-862f-b11d21ab341a"
    #client_id            = "043e5510-738f-4c30-8b9d-ee32578c7fe8"
    resource_group_name  = "s940-tfstate"
    storage_account_name = "s940radixinfra"
    container_name       = "infrastructure"
    key                  = "prod/post-clusters/terraform.tfstate"
  }
}

provider "azurerm" {
  subscription_id = "ded7ca41-37c8-4085-862f-b11d21ab341a"
  features {}
}

module "config" {
  source = "../../../modules/config"
}

module "clusters" {
  source              = "../../../modules/active-clusters"
  resource_group_name = "clusters" #TODO with code below after cluster in new RG module.config.cluster_resource_group
  subscription        = module.config.subscription
}

