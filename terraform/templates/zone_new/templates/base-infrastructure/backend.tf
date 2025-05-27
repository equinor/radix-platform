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
    tenant_id            = "${tenant_id}" # template
    subscription_id      = "${subscription_id}" # template
    resource_group_name  = "${subscription_shortname}-tfstate" # template
    storage_account_name = "${subscription_shortname}radixinfra" # template
    container_name       = "tfstate"
    key                  = "${zone}/base/terraform.tfstate" # template
    use_azuread_auth     = true                             # This enables RBAC instead of access keys
  }
}

provider "azurerm" {
  subscription_id     = "${subscription_id}" # template
  storage_use_azuread = true            # This enables RBAC instead of access keys
  features {}
}

