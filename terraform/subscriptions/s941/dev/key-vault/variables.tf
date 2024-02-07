variable "keyvaults" {
  description = "Key Vaults"
  type = map(object({
    resource_group              = optional(string, "common-dev")
    soft_delete_retention_days  = optional(number, 30)
    enable_rbac_authorization   = optional(bool, false)
    purge_protection_enabled    = optional(bool, true)
    network_acls_default_action = optional(string, "Allow")
    # access_policies = [
    #   {
    #     object_id = "37313aab-f26e-4cde-bea1-cb05203e4736"
    #     secret_permissions = [
    #       "Get",
    #     ]
    #     storage_permissions = []
    #     tenant_id           = local.external_outputs.global.data.tenant_id
    #   },
    #   {
    #     certificate_permissions = [
    #       "Get",
    #       "List",
    #     ]
    #     key_permissions = [
    #       "Get",
    #       "List",
    #     ]
    #     object_id = "61c128b9-e355-46a5-8e30-be40733d2e8b"
    #     secret_permissions = [
    #       "Get",
    #       "List",
    #     ]
    #     tenant_id = local.external_outputs.global.data.tenant_id
    #   },
    #   {
    #     certificate_permissions = [
    #       "Get",
    #       "List",
    #     ]
    #     key_permissions = [
    #       "Get",
    #       "List",
    #     ]
    #     object_id = "66ff1bda-3974-4637-91d1-da9de83e3dd0"
    #     secret_permissions = [
    #       "Get",
    #       "List",
    #     ]
    #     tenant_id = local.external_outputs.global.data.tenant_id
    #   },
    #   {
    #     object_id = "cfedc110-6bd8-4b9b-82ad-d17fe6a88665"
    #     secret_permissions = [
    #       "Get",
    #     ]
    #     tenant_id = local.external_outputs.global.data.tenant_id
    #   },
    #   {
    #     certificate_permissions = [
    #       "Get",
    #       "List",
    #       "Update",
    #       "Create",
    #       "Import",
    #       "Delete",
    #       "Recover",
    #       "Backup",
    #       "Restore",
    #       "ManageContacts",
    #       "ManageIssuers",
    #       "GetIssuers",
    #       "ListIssuers",
    #       "SetIssuers",
    #       "DeleteIssuers",
    #     ]
    #     key_permissions = [
    #       "Get",
    #       "List",
    #       "Update",
    #       "Create",
    #       "Import",
    #       "Delete",
    #       "Recover",
    #       "Backup",
    #       "Restore",
    #     ]
    #     object_id = "604bad73-c53b-4a95-ab17-d7953f75c8c3"
    #     secret_permissions = [
    #       "Get",
    #       "List",
    #       "Set",
    #       "Delete",
    #       "Recover",
    #       "Backup",
    #       "Restore",
    #     ]
    #     tenant_id = local.external_outputs.global.data.tenant_id
    #   },
    #   {
    #     object_id = "482b3662-b336-4041-8cea-9366175b7711"
    #     secret_permissions = [
    #       "Get",
    #     ]
    #     tenant_id = local.external_outputs.global.data.tenant_id
    #   },
    #   {
    #     certificate_permissions = [
    #       "Get",
    #       "List",
    #       "Update",
    #       "Create",
    #       "Import",
    #       "Delete",
    #       "Recover",
    #       "Backup",
    #       "Restore",
    #       "ManageContacts",
    #       "ManageIssuers",
    #       "GetIssuers",
    #       "ListIssuers",
    #       "SetIssuers",
    #       "DeleteIssuers",
    #     ]
    #     key_permissions = [
    #       "Get",
    #       "List",
    #       "Update",
    #       "Create",
    #       "Import",
    #       "Delete",
    #       "Recover",
    #       "Backup",
    #       "Restore",
    #     ]
    #     object_id = "a5dfa635-dc00-4a28-9ad9-9e7f1e56919d"
    #     secret_permissions = [
    #       "Get",
    #       "List",
    #       "Set",
    #       "Delete",
    #       "Recover",
    #       "Backup",
    #       "Restore",
    #     ]
    #     tenant_id = local.external_outputs.global.data.tenant_id
    #   },
    #   {
    #     object_id = "e1cab00e-9c12-4ce1-9882-842a57e89643"
    #     secret_permissions = [
    #       "Get",
    #       "List",
    #       "Set",
    #     ]
    #     tenant_id = local.external_outputs.global.data.tenant_id
    #   },
    #   {
    #     key_permissions = [
    #       "List",
    #       "Get",
    #     ]
    #     object_id = "3f201ab8-f0c4-4049-983c-1bf7d663d532"
    #     secret_permissions = [
    #       "Backup",
    #       "Restore",
    #     ]
    #     tenant_id = local.external_outputs.global.data.tenant_id
    #   },
    #   {
    #     object_id = "0d5c3b22-ee9b-4240-831e-9e5e5201d854"
    #     secret_permissions = [
    #       "Get",
    #     ]
    #     tenant_id = local.external_outputs.global.data.tenant_id
    #   },
    #   {
    #     object_id = "c527d489-b9c7-46db-aed7-bdd6ca27115d"
    #     secret_permissions = [
    #       "Get",
    #     ]
    #     tenant_id = local.external_outputs.global.data.tenant_id
    #   },
    #   {
    #     object_id = "917fe078-3ea4-4fc7-a728-fec7b41c155a"
    #     secret_permissions = [
    #       "Get",
    #     ]
    #     tenant_id = local.external_outputs.global.data.tenant_id
    #   },
    #   {
    #     object_id = "620c1a93-b744-4b26-bb0b-986c141fcc1b"
    #     secret_permissions = [
    #       "Get",
    #     ]
    #     tenant_id = local.external_outputs.global.data.tenant_id
    #   },
    #   {
    #     object_id = "dd4dd75c-6e56-4c2b-9404-e76d2c29c67f"
    #     secret_permissions = [
    #       "Get",
    #       "Set",
    #     ]
    #     tenant_id = local.external_outputs.global.data.tenant_id
    #   },
    #   {
    #     object_id = "17be8596-0d2f-445b-be4b-9fdbae8e046f"
    #     secret_permissions = [
    #       "Get",
    #     ]
    #     tenant_id = local.external_outputs.global.data.tenant_id
    #   },
    #   {
    #     object_id = "c488da80-c7bd-4751-b52e-cb9a852826bd"
    #     secret_permissions = [
    #       "Get",
    #     ]
    #     tenant_id = local.external_outputs.global.data.tenant_id
    #   },
    #   {
    #     object_id = "77afc085-6b69-495a-a756-45cefdbfdd80"
    #     secret_permissions = [
    #       "Get",
    #       "List",
    #     ]
    #     tenant_id = local.external_outputs.global.data.tenant_id
    #   }
    # ]
  }))
  default = {
    radix-vault-dev = {
      resource_group = "common"
    }
    radix-kv-dev = {
      resource_group            = "common-dev"
      enable_rbac_authorization = true
    }
  }

}