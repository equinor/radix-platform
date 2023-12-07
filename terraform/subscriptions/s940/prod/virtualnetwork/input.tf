locals {

  external_outputs = {
    common = data.terraform_remote_state.common.outputs
    clusters = data.terraform_remote_state.clusters
  }

  ## Backend Config
  backend = {
    resource_group_name  = "s940-tfstate"
    storage_account_name = "s940radixinfra"
    container_name       = "infrastructure"
  }
}
### Remote States
## Common
data "terraform_remote_state" "common" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "prod/common/terraform.tfstate" })
}

data "terraform_remote_state" "clusters" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "prod/clusters/terraform.tfstate" })
}