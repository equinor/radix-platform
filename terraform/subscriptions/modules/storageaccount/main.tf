terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.60.0, < 5.0.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = ">= 2.7.0"
    }
  }
}

# These resources used to be declared directly in this module.
moved {
  from = azurerm_storage_account.storageaccount
  to   = module.account.azurerm_storage_account.storageaccount
}

moved {
  from = azurerm_storage_account_network_rules.this
  to   = module.account.azurerm_storage_account_network_rules.this
}

moved {
  from = azurerm_monitor_diagnostic_setting.blob
  to   = module.account.azurerm_monitor_diagnostic_setting.blob
}

moved {
  from = azurerm_role_assignment.roleassignment
  to   = module.account.azurerm_role_assignment.roleassignment
}

moved {
  from = azurerm_data_protection_backup_instance_blob_storage.backupinstanceblobstorage
  to   = module.account.azurerm_data_protection_backup_instance_blob_storage.backupinstanceblobstorage
}

moved {
  from = azurerm_private_endpoint.this
  to   = module.account.azurerm_private_endpoint.this
}

moved {
  from = azurerm_private_dns_a_record.this
  to   = module.account.azurerm_private_dns_a_record.this
}

moved {
  from = azurerm_storage_management_policy.this
  to   = module.account.azurerm_storage_management_policy.this
}

module "account" {
  source                            = "../storageaccount-only"
  name                              = var.name
  resource_group_name               = var.resource_group_name
  location                          = var.location
  kind                              = var.kind
  tier                              = var.tier
  account_replication_type          = var.account_replication_type
  environment                       = var.environment
  subscription_shortname            = var.subscription_shortname
  public_network_access             = var.public_network_access
  change_feed_enabled               = var.change_feed_enabled
  change_feed_retention_in_days     = var.change_feed_retention_in_days
  versioning_enabled                = var.versioning_enabled
  container_delete_retention_policy = var.container_delete_retention_policy
  delete_retention_policy           = var.delete_retention_policy
  backup_center                     = var.backup_center
  backup                            = var.backup
  principal_id                      = var.principal_id
  vault_id                          = var.vault_id
  policyblobstorage_id              = var.policyblobstorage_id
  subnet_id                         = var.subnet_id
  virtual_network                   = var.virtual_network
  vnet_resource_group               = var.vnet_resource_group
  lifecycle_policy_rules            = var.lifecycle_policy_rules
  log_analytics_id                  = var.log_analytics_id
}

resource "azurerm_network_security_perimeter_association" "this" {
  name                                  = module.account.data.name
  access_mode                           = "Enforced"
  network_security_perimeter_profile_id = var.network_security_perimeter_profile_id
  resource_id                           = module.account.data.id
}

# azurerm < 5.5 only supports Enabled/Disabled; "Secured by perimeter" must be set via the ARM API.
resource "azapi_update_resource" "secured_by_perimeter" {
  type        = "Microsoft.Storage/storageAccounts@2023-05-01"
  resource_id = module.account.data.id

  body = {
    properties = {
      publicNetworkAccess = "SecuredByPerimeter"
    }
  }

  depends_on = [azurerm_network_security_perimeter_association.this]
}
