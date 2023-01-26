#######################################################################################
### Zone and cluster settings
###

RADIX_ZONE = "prod"

#######################################################################################
### Resource groups
###

AZ_LOCATION              = "northeurope"
AZ_RESOURCE_GROUP_COMMON = "common"

#######################################################################################
### Storage Accounts
###

storage_accounts = {
  "costallocationprodsqllog" = {
    name          = "costallocationprodsqllog"
    rg_name       = "cost-allocation"
    backup_center = true
  }
  "radixflowlogsc2prod" = {
    name          = "radixflowlogsc2prod"
    rg_name       = "logs-westeurope"
    location      = "westeurope"
    backup_center = true
    life_cycle    = false
  }
  "radixflowlogsprod" = {
    name          = "radixflowlogsprod"
    rg_name       = "Logs"
    backup_center = true
    life_cycle    = false
  }
  "radixgrafanabackup" = {
    name          = "radixgrafanabackup"
    rg_name       = "monitoring"
    backup_center = true
  }
  "radixveleroc2prod" = {
    name          = "radixveleroc2prod"
    rg_name       = "backups"
    location      = "westeurope"
    repl          = "GRS"
    kind          = "BlobStorage"
    backup_center = false
  }
  "radixveleroprod" = {
    name          = "radixveleroprod"
    rg_name       = "backups"
    repl          = "LRS"
    kind          = "BlobStorage"
    backup_center = false
  }
  "s940radixinfra" = {
    name          = "s940radixinfra"
    rg_name       = "s940-tfstate"
    repl          = "RAGRS"
    backup_center = true
  }
  "s940sqllogsc2prod" = {
    name          = "s940sqllogsc2prod"
    rg_name       = "common-westeurope"
    location      = "westeurope"
    backup_center = true
    life_cycle    = false
  }
  "s940sqllogsprod" = {
    name          = "s940sqllogsprod"
    rg_name       = "common"
    backup_center = true
    life_cycle    = false
  }
}

#######################################################################################
### Virtual networks
###

vnets = {
  "vnet-c2-prod-34" = {
    vnet_name   = "vnet-c2-prod-34"
    subnet_name = "subnet-c2-prod-34"
    rg_name     = "clusters-westeurope"
  }
  "vnet-eu-34" = {
    vnet_name   = "vnet-eu-34"
    subnet_name = "subnet-eu-34"
  }
  "aks-vnet-35748448" = {
    vnet_name   = "aks-vnet-35748448"
    subnet_name = "aks-subnet"
    rg_name     = "MC_monitoring_ext-mon-14_northeurope"
  }
}
