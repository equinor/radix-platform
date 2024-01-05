locals {
  external_outputs = {
    global = data.terraform_remote_state.global.outputs
  }

  flattened_storageaccounts = {
    for key, value in var.storageaccounts : key => {
      name                     = key
      resource_group_name      = value.resource_group_name
      location                 = value.location
      account_tier             = value.account_tier
      account_replication_type = value.account_replication_type
      kind                     = value.kind
      change_feed_enabled      = value.change_feed_enabled
      versioning_enabled       = value.versioning_enabled
      enable_backup            = value.enable_backup
      roleassignment           = value.roleassignment
      # principal_id             = value.principal_id

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
