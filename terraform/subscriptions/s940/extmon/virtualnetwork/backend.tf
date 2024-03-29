terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "<=3.69.0"
    }
  }

  backend "azurerm" {
    tenant_id       = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
    subscription_id = "ded7ca41-37c8-4085-862f-b11d21ab341a"
    #client_id            = "043e5510-738f-4c30-8b9d-ee32578c7fe8"
    resource_group_name  = "common-extmon"
    storage_account_name = "radixstateextmon"
    container_name       = "infrastructure"
    key                  = "extmon/virtualnetwork/terraform.tfstate"
  }
}

provider "azurerm" {
  subscription_id = "ded7ca41-37c8-4085-862f-b11d21ab341a"
  features {
  }
}
