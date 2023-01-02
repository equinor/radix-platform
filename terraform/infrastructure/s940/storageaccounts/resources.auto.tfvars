storage_accounts = {
  "backupsstorageaccount" = {
    name          = "backupsstorageaccount"
    rg_name       = "monitoring"
    kind          = "Storage"
    life_cycle    = false
    container_delete_retention_policy = true
  }
  "costallocationprodsqllog" = {
    name          = "costallocationprodsqllog"
    rg_name       = "cost-allocation"
    allow_nested_items_to_be_public = false
    backup_center = true
  }
  "radixflowlogsc2prod" = {
    name          = "radixflowlogsc2prod"
    rg_name       = "logs-westeurope"
    location      = "westeurope"
    life_cycle    = false
  }
  "radixflowlogsprod" = {
    name          = "radixflowlogsprod"
    rg_name       = "Logs"
    life_cycle    = false
  }
  "radixgrafanabackup" = {
    name          = "radixgrafanabackup"
    rg_name       = "monitoring"
    delete_retention_policy = true
  }
  "radixsqllogsprod" = {
    name          = "radixsqllogsprod"
    rg_name       = "rg-radix-shared-prod"
    location      = "norwayeast"
    delete_retention_policy = true
  }
  "radixveleroc2prod" = {
    name          = "radixveleroc2prod"
    rg_name       = "velero-backups-westeurope"
    location      = "westeurope"
    repl          = "GRS"
    kind          = "BlobStorage"
    container_delete_retention_policy = true
  }
  "radixveleroprod" = {
    name          = "radixveleroprod"
    rg_name       = "Velero_Backups"
    repl          = "GRS"
    kind          = "BlobStorage"
    container_delete_retention_policy = true
  }
  "s940sqllogsc2prod" = {
    name          = "s940sqllogsc2prod"
    rg_name       = "common-westeurope"
    location      = "westeurope"
    life_cycle    = false
  }
  "s940sqllogsprod" = {
    name          = "s940sqllogsprod"
    rg_name       = "common"
    life_cycle    = false
  }
}