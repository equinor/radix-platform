locals {

  external_outputs = {
    common   = data.terraform_remote_state.common.outputs
  //  keyvault = data.terraform_remote_state.keyvault.outputs.data
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
  { key = "dev/common/terraform.tfstate" })
}

#data "terraform_remote_state" "keyvault" {
#  backend = "azurerm"
#  config = merge(
#    local.backend,
#  { key = "playground/key-vault/terraform.tfstate" })
#}
#
#
#


