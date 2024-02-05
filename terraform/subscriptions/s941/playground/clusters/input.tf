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
    resource_group_name  = "s941-tfstate"
    storage_account_name = "s941radixinfra"
    container_name       = "infrastructure"
    subscription_id      = "16ede44b-1f74-40a5-b428-46cca9a5741b"
  }
}

data "terraform_remote_state" "common" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "playground/common/terraform.tfstate" })
}

data "terraform_remote_state" "global" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "dev/globals/terraform.tfstate" })
}

