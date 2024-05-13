#######################################################################################
### Protection Vault
###

resource "azurerm_data_protection_backup_vault" "backupvault" {
  name                = var.name
  resource_group_name = var.resource_group_name
  location            = var.location
  datastore_type      = "VaultStore"
  redundancy          = "LocallyRedundant"

  identity {
    type = "SystemAssigned"

  }
  tags = {
    IaC = "terraform"
  }

}

#######################################################################################
### Protection Backup Policy
###

resource "azurerm_data_protection_backup_policy_blob_storage" "policyblobstorage" {
  name               = var.policyblobstoragename
  vault_id           = azurerm_data_protection_backup_vault.backupvault.id
  retention_duration = "P30D"
}

#######################################################################################
### Lock
###

resource "azurerm_management_lock" "backupvault" {
  name       = "${var.name}-lock"
  scope      = azurerm_data_protection_backup_vault.backupvault.id
  lock_level = "CanNotDelete"
  notes      = "To prevent ${var.name} from being deleted"
  depends_on = [azurerm_data_protection_backup_vault.backupvault]
}