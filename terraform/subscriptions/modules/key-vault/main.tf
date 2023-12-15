module "kv" {
  source                     = "github.com/equinor/terraform-azurerm-key-vault?ref=v11.2.0"
  vault_name                 = var.vault_name
  log_analytics_workspace_id = var.log_analytics_workspace_id
  resource_group_name        = var.resource_group_name
  location                   = var.location
  enable_rbac_authorization  = false
  purge_protection_enabled   = true

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
  #access_policy             = var.access_policies
}

# output "test" {
#   value = module.keyvault.module.kv.azurerm_key_vault.this
  
# }
# locals {
#   access_policies = [
#     for p in var.access_policies : {
#       tenant_id               = data.azurerm_client_config.current.tenant_id
#       application_id          = ""
#       object_id               = p.object_id
#       secret_permissions      = p.secret_permissions
#       certificate_permissions = p.certificate_permissions
#       key_permissions         = p.key_permissions
#       storage_permissions     = []
#     }
#   ]
# }

# data "azurerm_client_config" "current" {}

# resource "azurerm_key_vault" "this" {
#   name                = var.vault_name
#   location            = var.location
#   resource_group_name = var.resource_group_name
#   sku_name            = "standard"
#   tenant_id           = data.azurerm_client_config.current.tenant_id

#   soft_delete_retention_days = var.soft_delete_retention_days
#   purge_protection_enabled   = var.purge_protection_enabled

#   enabled_for_deployment          = false
#   enabled_for_disk_encryption     = false
#   enabled_for_template_deployment = false

#   access_policy             = local.access_policies
#   enable_rbac_authorization = var.enable_rbac_authorization

#   public_network_access_enabled = var.public_network_access_enabled

#   network_acls {
#     default_action             = var.network_acls_default_action
#     bypass                     = var.network_acls_bypass_azure_services ? "AzureServices" : "None"
#     ip_rules                   = var.network_acls_ip_rules
#     virtual_network_subnet_ids = var.network_acls_virtual_network_subnet_ids
#   }

#   tags = var.tags
# }

# resource "azurerm_monitor_diagnostic_setting" "this" {
#   name                       = var.diagnostic_setting_name
#   target_resource_id         = azurerm_key_vault.this.id
#   log_analytics_workspace_id = var.log_analytics_workspace_id

#   # "log_analytics_destination_type" is unconfigurable for Key Vault.
#   # Ref: https://registry.terraform.io/providers/hashicorp/azurerm/3.65.0/docs/resources/monitor_diagnostic_setting#log_analytics_destination_type
#   log_analytics_destination_type = null

#   dynamic "enabled_log" {
#     for_each = toset(var.diagnostic_setting_enabled_log_categories)

#     content {
#       category = enabled_log.value
#     }
#   }

#   metric {
#     category = "AllMetrics"
#     enabled  = true

#     retention_policy {
#       days    = 0
#       enabled = false
#     }
#   }
# }
