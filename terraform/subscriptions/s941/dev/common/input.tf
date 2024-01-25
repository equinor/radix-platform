locals {
  external_outputs = {
    global         = data.terraform_remote_state.global.outputs
    virtualnetwork = data.terraform_remote_state.virtualnetwork.outputs
  }

  flattened_roleassignment = {
    for key, value in var.storageaccounts : key => {
      backup = false
    }
  }

  ## Backend Config
  backend = {
    resource_group_name  = "s941-tfstate"
    storage_account_name = "s941radixinfra"
    container_name       = "infrastructure"
  }
}
### Remote States
data "terraform_remote_state" "global" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "dev/globals/terraform.tfstate" })
}

data "terraform_remote_state" "virtualnetwork" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "dev/virtualnetwork/terraform.tfstate" })
}
