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
### Resouce Groups
###

resource_groups = {
  "backups" = {
    name = "backups"
  }
  "cluster-vnet-hub-prod" = {
    name = "cluster-vnet-hub-prod"
  }
  "clusters" = {
    name = "clusters"
  }
  "common" = {
    name = "common"
  }
  "cost-allocation" = {
    name = "cost-allocation"
  }
  "monitoring" = {
    name = "monitoring"
  }
  "s940-tfstate" = {
    name = "s940-tfstate"
  }
  "vulnerability-scan" = {
    name = "vulnerability-scan"
  }
  "clusters-westeurope" = {
    name     = "clusters-westeurope"
    location = "westeurope"
  }
  "common-westeurope" = {
    name     = "common-westeurope"
    location = "westeurope"
  }
  "cost-allocation-westeurope" = {
    name     = "cost-allocation-westeurope"
    location = "westeurope"
  }
  "dashboards" = {
    name     = "dashboards"
    location = "westeurope"
  }
  "Logs" = {
    name     = "Logs"
    location = "westeurope"
  }
  "logs-westeurope" = {
    name     = "logs-westeurope"
    location = "westeurope"
  }
  "monitoring-westeurope" = {
    name     = "monitoring-westeurope"
    location = "westeurope"
  }
  "radix-private-links-c2-prod" = {
    name     = "radix-private-links-c2-prod"
    location = "westeurope"
  }
  "rg-protection-we" = {
    name     = "rg-protection-we"
    location = "westeurope"
  }
  "S940-log" = {
    name     = "S940-log"
    location = "westeurope"
  }
  "vulnerability-scan-westeurope" = {
    name     = "vulnerability-scan-westeurope"
    location = "westeurope"
  }
}

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
### SQL Server
###

sql_server = {
  "sql-radix-cost-allocation-c2-prod" = {
    name                = "sql-radix-cost-allocation-c2-prod"
    rg_name             = "cost-allocation-westeurope"
    location            = "westeurope"
    db_admin            = "radix-cost-allocation-db-admin"
    minimum_tls_version = "Disabled"
    tags = {
      "displayName" = "SqlServer"
    }
    identity = false
  }
  "sql-radix-cost-allocation-prod" = {
    name                = "sql-radix-cost-allocation-prod"
    rg_name             = "cost-allocation"
    db_admin            = "radix-cost-allocation-db-admin"
    minimum_tls_version = "Disabled"
    tags = {
      "displayName" = "SqlServer"
    }
  }
  "sql-radix-vulnerability-scan-c2-prod" = {
    name     = "sql-radix-vulnerability-scan-c2-prod"
    rg_name  = "vulnerability-scan-westeurope"
    location = "westeurope"
    db_admin = "radix-vulnerability-scan-db-admin"
    identity = false
  }
  "sql-radix-vulnerability-scan-prod" = {
    name     = "sql-radix-vulnerability-scan-prod"
    rg_name  = "vulnerability-scan"
    db_admin = "radix-vulnerability-scan-db-admin"
  }
}

# key_vault = {
#   "radix-vault-c2-prod" = {
#     name    = "radix-vault-c2-prod"
#     rg_name = "common-westeurope"
#   }
#   "radix-vault-prod" = {
#     name    = "radix-vault-prod"
#     rg_name = "common"
#   }
# }

#######################################################################################
### MYSQL Flexible Server
###

mysql_flexible_server = {
  "s940-radix-grafana-c2-prod" = {
    name     = "s940-radix-grafana-c2-prod"
    location = "westeurope"
    secret   = "s940-radix-grafana-c2-prod-mysql-admin-pwd"
  }
  "s940-radix-grafana-extmon-prod" = {
    name   = "s940-radix-grafana-extmon-prod"
    secret = "s940-radix-grafana-extmon-prod-mysql-admin-pwd"
  }
  "s940-radix-grafana-platform-prod" = {
    name   = "s940-radix-grafana-platform-prod"
    secret = "s940-radix-grafana-platform-prod-mysql-admin-pwd"
  }
}

key_secrets = {
  "sql-radix-cost-allocation-c2-prod" = {
    name  = "radix-cost-allocation-db-admin"
    vault = "radix-vault-c2-prod"
  }
  "sql-radix-cost-allocation-prod" = {
    name  = "radix-cost-allocation-db-admin"
    vault = "radix-vault-prod"
  }
  "sql-radix-vulnerability-scan-c2-prod" = {
    name  = "radix-vulnerability-scan-db-admin"
    vault = "radix-vault-c2-prod"
  }
  "sql-radix-vulnerability-scan-prod" = {
    name  = "radix-vulnerability-scan-db-admin"
    vault = "radix-vault-prod"
  }
}

#######################################################################################
### Key Vault
###

key_vault = {
  "kv-radix-monitoring-prod" = {
    name    = "kv-radix-monitoring-prod"
    rg_name = "monitoring"
  }
}

firewall_rules = {
  "equinor-wifi" = {
    start_ip_address = "143.97.110.1"
    end_ip_address   = "143.97.110.1"
  }
  "bouvet-trondheim" = {
    start_ip_address = "85.19.71.228"
    end_ip_address   = "85.19.71.228"
  }
  "equinor_vpn" = {
    start_ip_address = "143.97.2.35"
    end_ip_address   = "143.97.2.35"
  }
  "equinor_wifi" = {
    start_ip_address = "143.97.2.129"
    end_ip_address   = "143.97.2.129"
  }
  "Enable-Azure-services" = {
    start_ip_address = "0.0.0.0"
    end_ip_address   = "0.0.0.0"
  }
}

#######################################################################################
### SQL Database
###

sql_database = {
  "sql-radix-cost-allocation-c2-prod" = {
    name     = "sqldb-radix-cost-allocation"
    server   = "sql-radix-cost-allocation-c2-prod"
    tags = {
      "displayName" = "Database"
    }
  }
  "sql-radix-cost-allocation-prod" = {
    name   = "sqldb-radix-cost-allocation"
    server = "sql-radix-cost-allocation-prod"
    tags = {
      "displayName" = "Database"
    }
  }
  "sql-radix-vulnerability-scan-c2-prod" = {
    name     = "radix-vulnerability-scan"
    server   = "sql-radix-vulnerability-scan-c2-prod"
    sku_name = "S0"
  }
  "sql-radix-vulnerability-scan-prod" = {
    name   = "radix-vulnerability-scan"
    server = "sql-radix-vulnerability-scan-prod"
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
