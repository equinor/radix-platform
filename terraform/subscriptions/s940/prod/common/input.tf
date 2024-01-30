locals {
  external_outputs = {
    global         = data.terraform_remote_state.global.outputs
    virtualnetwork = data.terraform_remote_state.virtualnetwork.outputs
  }

  backend = {
    resource_group_name  = "s940-tfstate"
    storage_account_name = "s940radixinfra"
    container_name       = "infrastructure"
  }

}
data "terraform_remote_state" "global" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "prod/globals/terraform.tfstate" })
}

data "terraform_remote_state" "virtualnetwork" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "prod/virtualnetwork/terraform.tfstate" })
}
