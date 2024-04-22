locals {
  external_outputs = {
    virtualnetwork = data.terraform_remote_state.virtualnetwork.outputs
  }

  ## Backend Config
  backend = {
    resource_group_name  = "s941-tfstate"
    storage_account_name = "s941radixinfra"
    container_name       = "infrastructure"
    subscription_id      = "16ede44b-1f74-40a5-b428-46cca9a5741b"
  }
}

data "terraform_remote_state" "virtualnetwork" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "playground/virtualnetwork/terraform.tfstate" })
}
