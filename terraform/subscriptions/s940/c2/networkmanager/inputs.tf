locals {
  external_outputs = {
    global         = data.terraform_remote_state.global.outputs
    common         = data.terraform_remote_state.common.outputs
    networkmanager = data.terraform_remote_state.networkmanager.outputs
    virtualnetwork = data.terraform_remote_state.virtualnetwork.outputs
    clusters       = data.terraform_remote_state.clusters.outputs
  }
  ## Backend Config
  backend = {
    resource_group_name  = "s940-tfstate"
    storage_account_name = "s940radixinfra"
    container_name       = "infrastructure"
    subscription_id      = "ded7ca41-37c8-4085-862f-b11d21ab341a"
  }
}

### Remote States
## Common
data "terraform_remote_state" "common" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "c2/common/terraform.tfstate" })
}

## Networkmananger
data "terraform_remote_state" "networkmanager" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "prod/networkmanager/terraform.tfstate" })
}

data "terraform_remote_state" "virtualnetwork" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "c2/virtualnetwork/terraform.tfstate" })
}

data "terraform_remote_state" "clusters" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "c2/clusters/terraform.tfstate" })
}

data "terraform_remote_state" "global" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "prod/globals/terraform.tfstate" })
}
