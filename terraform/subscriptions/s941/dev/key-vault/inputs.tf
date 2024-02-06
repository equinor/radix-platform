locals {

  log_analytics_workspace = {
    name           = "radix-logs-playground"
    resource_group = "common-playground"
  }

  key_vault = {
    name                        = "radix-vault-dev"
    resource_group              = local.external_outputs.common.data.resource_group
    soft_delete_retention_days  = 30
    enable_rbac_authorization   = false
    purge_protection_enabled    = true
    network_acls_default_action = "Allow"
    access_policies = [
      {
        object_id = "37313aab-f26e-4cde-bea1-cb05203e4736"
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
        ]
        key_permissions = [
          "Get",
          "List",
        ]
        object_id = "61c128b9-e355-46a5-8e30-be40733d2e8b"
        secret_permissions = [
          "Get",
          "List",
        ]
        tenant_id = local.external_outputs.global.data.tenant_id
      },
      {
        certificate_permissions = [
          "Get",
          "List",
        ]
        key_permissions = [
          "Get",
          "List",
        ]
        object_id = "66ff1bda-3974-4637-91d1-da9de83e3dd0"
        secret_permissions = [
          "Get",
          "List",
        ]
        tenant_id = local.external_outputs.global.data.tenant_id
      },
      {
        object_id = "cfedc110-6bd8-4b9b-82ad-d17fe6a88665"
        secret_permissions = [
          "Get",
        ]
        tenant_id = local.external_outputs.global.data.tenant_id
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
        object_id = "604bad73-c53b-4a95-ab17-d7953f75c8c3"
        secret_permissions = [
          "Get",
          "List",
          "Set",
          "Delete",
          "Recover",
          "Backup",
          "Restore",
        ]
        tenant_id = local.external_outputs.global.data.tenant_id
      },
      {
        object_id = "482b3662-b336-4041-8cea-9366175b7711"
        secret_permissions = [
          "Get",
        ]
        tenant_id = local.external_outputs.global.data.tenant_id
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
        object_id = "a5dfa635-dc00-4a28-9ad9-9e7f1e56919d"
        secret_permissions = [
          "Get",
          "List",
          "Set",
          "Delete",
          "Recover",
          "Backup",
          "Restore",
        ]
        tenant_id = local.external_outputs.global.data.tenant_id
      },
      {
        object_id = "e1cab00e-9c12-4ce1-9882-842a57e89643"
        secret_permissions = [
          "Get",
          "List",
          "Set",
        ]
        tenant_id = local.external_outputs.global.data.tenant_id
      },
      {
        key_permissions = [
          "List",
          "Get",
        ]
        object_id = "3f201ab8-f0c4-4049-983c-1bf7d663d532"
        secret_permissions = [
          "Backup",
          "Restore",
        ]
        tenant_id = local.external_outputs.global.data.tenant_id
      },
      {
        object_id = "0d5c3b22-ee9b-4240-831e-9e5e5201d854"
        secret_permissions = [
          "Get",
        ]
        tenant_id = local.external_outputs.global.data.tenant_id
      },
      {
        object_id = "c527d489-b9c7-46db-aed7-bdd6ca27115d"
        secret_permissions = [
          "Get",
        ]
        tenant_id = local.external_outputs.global.data.tenant_id
      },
      {
        object_id = "917fe078-3ea4-4fc7-a728-fec7b41c155a"
        secret_permissions = [
          "Get",
        ]
        tenant_id = local.external_outputs.global.data.tenant_id
      },
      {
        object_id = "620c1a93-b744-4b26-bb0b-986c141fcc1b"
        secret_permissions = [
          "Get",
        ]
        tenant_id = local.external_outputs.global.data.tenant_id
      },
      {
        object_id = "dd4dd75c-6e56-4c2b-9404-e76d2c29c67f"
        secret_permissions = [
          "Get",
          "Set",
        ]
        tenant_id = local.external_outputs.global.data.tenant_id
      },
      {
        object_id = "17be8596-0d2f-445b-be4b-9fdbae8e046f"
        secret_permissions = [
          "Get",
        ]
        tenant_id = local.external_outputs.global.data.tenant_id
      },
      {
        object_id = "c488da80-c7bd-4751-b52e-cb9a852826bd"
        secret_permissions = [
          "Get",
        ]
        tenant_id = local.external_outputs.global.data.tenant_id
      }
    ]
  }

  external_outputs = {
    global = data.terraform_remote_state.global.outputs
    common = data.terraform_remote_state.common.outputs
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

data "terraform_remote_state" "global" {
  backend = "azurerm"
  config = merge(
    local.backend,
  { key = "dev/globals/terraform.tfstate" })
}
