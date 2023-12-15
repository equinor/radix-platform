locals {

  access_policies = [
    for p in local.key_vault.access_policies : {
      tenant_id               = ""
      application_id          = ""
      object_id               = p.object_id
      # secret_permissions      = p.secret_permissions
      # certificate_permissions = p.certificate_permissions
      # key_permissions         = p.key_permissions
      # storage_permissions     = []
    }
  ]

  log_analytics_workspace = {
    name           = "log-key-vault"
    resource_group = "Logs"
  }

  key_vault = {
    name           = "radix-vault-prod"
    resource_group = "common"
    access_policies = [
      {
        object_id = "2784c69e-a017-4333-87e3-fa22cb7d77d9"
        secret_permissions = ["Get"]
        tenant_id = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
      }
    ]
  }

  external_outputs = {
    global = data.terraform_remote_state.global.outputs
    common = data.terraform_remote_state.common.outputs

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

data "terraform_remote_state" "global" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "prod/globals/terraform.tfstate" })
}
