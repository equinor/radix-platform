locals {
  external_outputs = {
    global = data.terraform_remote_state.global.outputs
    common = data.terraform_remote_state.common.outputs

  }
  flattened_clusters = {
    for key, value in var.clusters : key => {
      name                       = key
      resource_group_name        = value.resource_group_name
      location                   = value.location
      destination_address_prefix = value.destination_address_prefix
    }
  }
  backend = {
    resource_group_name  = "s940-tfstate"
    storage_account_name = "s940radixinfra"
    container_name       = "infrastructure"
    subscription_id      = "ded7ca41-37c8-4085-862f-b11d21ab341a"
  }
}

data "terraform_remote_state" "common" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "c2/common/terraform.tfstate" })
}

data "terraform_remote_state" "global" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "prod/globals/terraform.tfstate" })
}

