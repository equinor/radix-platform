locals {

  log_analytics_workspace = {
    name           = "log-key-vault"
    resource_group = "Logs"
  }

  key_vault = {
    name                        = "radix-vault-prod"
    resource_group              = "common"
    soft_delete_retention_days  = 30
    enable_rbac_authorization   = false
    purge_protection_enabled    = true
    network_acls_default_action = "Allow"
    access_policies = [
      {
        object_id          = "2784c69e-a017-4333-87e3-fa22cb7d77d9"
        secret_permissions = ["Get"]
        tenant_id          = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
      },
      {
        object_id          = "482a5884-89e2-4ec7-bf16-6de95b710fe5"
        secret_permissions = ["Get"]
        tenant_id          = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
      },
      {
        object_id = "ebea99a3-2291-4bca-8f1e-38e85d5f2961"
        secret_permissions = [
          "Get",
          "List",
          "Set",
          "Delete",
          "Recover",
          "Backup",
          "Restore",
        ]
        tenant_id = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
      },
      {
        certificate_permissions = [
          "Get",
          "List",
          "Update",
          "Create",
          "Import",
          "Delete",
          "Recover",
          "Backup",
          "Restore",
          "ManageContacts",
          "ManageIssuers",
          "GetIssuers",
          "ListIssuers",
          "SetIssuers",
          "DeleteIssuers",
        ]
        key_permissions = [
          "Get",
          "List",
          "Update",
          "Create",
          "Import",
          "Delete",
          "Recover",
          "Backup",
          "Restore",
        ]
        object_id = "be5526de-1b7d-4389-b1ab-a36a99ef5cc5"
        secret_permissions = [
          "Get",
          "List",
          "Set",
          "Delete",
          "Recover",
          "Backup",
          "Restore",
        ]
        tenant_id = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
      },
      {
        object_id          = "972868b6-f15e-4440-9063-6b3da13ccb93"
        secret_permissions = ["Get"]
        tenant_id          = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
      },
      {
        object_id          = "af156134-0e5b-4d3c-b8e6-1ef112c68559"
        secret_permissions = ["Get"]
        tenant_id          = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
      },
      {
        object_id          = "8ab3d792-1724-4e5f-aa27-76a2b943c502"
        secret_permissions = ["Get"]
        tenant_id          = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
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
