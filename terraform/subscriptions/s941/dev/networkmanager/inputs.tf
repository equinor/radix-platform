locals {
  policy_notcontains_name = "playground"
  flattened_publicipprefix = {
    for key, value in var.publicipprefix : key => {
      name  = key
      zones = value.zones
    }
  }

  external_outputs = {
    global         = data.terraform_remote_state.global.outputs
    common         = data.terraform_remote_state.common.outputs
    networkmanager = data.terraform_remote_state.networkmanager.outputs
    virtualnetwork = data.terraform_remote_state.virtualnetwork.outputs
    clusters       = data.terraform_remote_state.clusters.outputs
  }
  ## Backend Config
  backend = {
    resource_group_name  = "s941-tfstate"
    storage_account_name = "s941radixinfra"
    container_name       = "infrastructure"
    subscription_id      = "16ede44b-1f74-40a5-b428-46cca9a5741b"
  }
}

### Remote States
## Common
data "terraform_remote_state" "common" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "dev/common/terraform.tfstate" })
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
  { key = "dev/virtualnetwork/terraform.tfstate" })
}

data "terraform_remote_state" "clusters" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "dev/clusters/terraform.tfstate" })
}

data "terraform_remote_state" "global" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "dev/globals/terraform.tfstate" })
}

