locals {
  external_outputs = {
    global   = data.terraform_remote_state.global.outputs
    common   = data.terraform_remote_state.common.outputs
    clusters = data.terraform_remote_state.clusters.outputs
  }

  ## Backend Config
    backend = {
    resource_group_name  = "common-extmon"
    storage_account_name = "radixstateextmon"
    container_name       = "infrastructure"
  }
}
### Remote States
## Common
data "terraform_remote_state" "common" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "extmon/common/terraform.tfstate" })
}

data "terraform_remote_state" "clusters" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "extmon/clusters/terraform.tfstate" })
}

data "terraform_remote_state" "global" {
  backend = "azurerm"
  config = {
    resource_group_name  = "s940-tfstate"
    storage_account_name = "s940radixinfra"
    container_name       = "infrastructure"
    key = "prod/globals/terraform.tfstate" }
}
