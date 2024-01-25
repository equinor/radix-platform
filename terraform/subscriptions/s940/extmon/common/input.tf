locals {
  external_outputs = {
    global = data.terraform_remote_state.global.outputs
    # virtualnetwork = data.terraform_remote_state.virtualnetwork.outputs
  }

  backend = {
    resource_group_name  = "common-extmon"
    storage_account_name = "radixstateextmon"
    container_name       = "infrastructure"
  }

}
data "terraform_remote_state" "global" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "prod/globals/terraform.tfstate" })
}
