locals {

  log_analytics_workspace = {
    name           = "log-key-vault"
    resource_group = "logs-westeurope"
  }

  key_vault = {
    name                        = "radix-vault-c2-prod"
    resource_group              = "common-westeurope"
    soft_delete_retention_days  = 30
    enable_rbac_authorization   = false
    purge_protection_enabled    = true
    network_acls_default_action = "Allow"
    access_policies = [
      {
        object_id = "482a5884-89e2-4ec7-bf16-6de95b710fe5"
        secret_permissions = [
          "Get",
        ]
        storage_permissions = []
        tenant_id           = local.external_outputs.global.data.tenant_id
      },
      {
        object_id = "2784c69e-a017-4333-87e3-fa22cb7d77d9"
        secret_permissions = [
          "Get",
        ]
        storage_permissions = []
        tenant_id           = local.external_outputs.global.data.tenant_id
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
          "GetRotationPolicy",
          "SetRotationPolicy",
          "Rotate",
          "Decrypt",
          "Encrypt",
          "UnwrapKey",
          "WrapKey",
          "Verify",
          "Sign",
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
        storage_permissions = []
        tenant_id           = local.external_outputs.global.data.tenant_id
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
          "Decrypt",
          "Encrypt",
          "UnwrapKey",
          "WrapKey",
          "Verify",
          "Sign",
          "Rotate",
          "GetRotationPolicy",
          "SetRotationPolicy",
        ]
        object_id = "5d0c1684-1d9d-49fc-875a-0eee747f5de6"
        secret_permissions = [
          "Get",
          "List",
          "Set",
          "Delete",
          "Recover",
          "Backup",
          "Restore",
        ]
        storage_permissions = [
          "all",
        ]
        tenant_id = local.external_outputs.global.data.tenant_id
      },
      {
        object_id = "bc5e10a1-ff38-4139-bd4d-0c7300102b61"
        secret_permissions = [
          "Get",
        ]
        storage_permissions = []
        tenant_id           = local.external_outputs.global.data.tenant_id
      },
      {
        object_id = "8ab3d792-1724-4e5f-aa27-76a2b943c502"
        secret_permissions = [
          "Get",
        ]
        storage_permissions = []
        tenant_id           = local.external_outputs.global.data.tenant_id
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
  { key = "c2/common/terraform.tfstate" })
}

data "terraform_remote_state" "global" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "prod/globals/terraform.tfstate" })
}
