terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">=3.110.0"
    }
    azapi = {
      source = "Azure/azapi"
    }
  }

  backend "azurerm" {
    tenant_id            = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
    subscription_id      = "ded7ca41-37c8-4085-862f-b11d21ab341a"
    resource_group_name  = "s940-tfstate"
    storage_account_name = "s940radixinfra"
    container_name       = "infrastructure"
    key                  = "c2/post-clusters/terraform.tfstate"
    use_azuread_auth     = true # This enables RBAC instead of access keys
  }
}

provider "azuread" {
  tenant_id = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
}

provider "azurerm" {
  subscription_id = "ded7ca41-37c8-4085-862f-b11d21ab341a"
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

data "azuread_service_principal" "this" {
  display_name = "radix-ar-resource-lock-operator-prod"
}

data "azurerm_role_definition" "this" {
  name = "Omnia Authorization Locks Operator"
}

data "azuread_group" "radix" {
  display_name     = "Radix"
  security_enabled = false
}
