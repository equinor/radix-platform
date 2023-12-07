locals {
  ## Stack
  stack = {
    name = "clusters"
  }

  external_outputs = {
    common = data.terraform_remote_state.common.outputs
    networkmanager = data.terraform_remote_state.networkmanager
    virtualnetwork = data.terraform_remote_state.virtualnetwork
    clusters       = data.terraform_remote_state.clusters
  }
  ## Backend Config
   backend = {
    resource_group_name  = "s941-tfstate"
    storage_account_name = "s941radixinfra"
    container_name       = "infrastructure"
  }
}

### Remote States
## Common
data "terraform_remote_state" "common" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "playground/common/terraform.tfstate" })
}

## Networkmananger
data "terraform_remote_state" "networkmanager" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "dev/networkmanager/terraform.tfstate" })
}

## Virtualnetwork
data "terraform_remote_state" "virtualnetwork" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "playground/virtualnetwork/terraform.tfstate" })
}

data "terraform_remote_state" "clusters" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "playground/clusters/terraform.tfstate" })
}
