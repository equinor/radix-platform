#######################################################################################
### Zone and cluster settings
###

AZ_LOCATION = "northeurope"
RADIX_ZONE  = "prod"

K8S_ENVIROMENTS = {
  "prod" = { "name" = "prod", "resourceGroup" = "clusters" },
  "c2"   = { "name" = "c2", "resourceGroup" = "clusters-westeurope" }
}
#######################################################################################
### Resource groups
###

AZ_RESOURCE_GROUP_COMMON = "common"

#######################################################################################
### Shared environment, az region and az subscription
###

AZ_SUBSCRIPTION_ID        = "ded7ca41-37c8-4085-862f-b11d21ab341a"
AZ_TENANT_ID              = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
AZ_SUBSCRIPTION_SHORTNAME = "s940"

#######################################################################################
### AAD
###

AAD_RADIX_GROUP = "radix"

#######################################################################################
### Managed Identities
###

managed_identity = {
  "id-radix-logicapp-operator-prod" = {
    name    = "id-radix-logicapp-operator-prod"
    rg_name = "Logs"
  }
  "id-radix-logicapp-operator-c2" = {
    name     = "id-radix-logicapp-operator-c2"
    location = "westeurope"
    rg_name  = "logs-westeurope"
  }
}

#######################################################################################
### Log Analytics
###

loganalytics = {
  "s940-northeurope-diagnostics" = {
    name             = "s940-northeurope-diagnostics"
    rg_name          = "Logs"
    managed_identity = true
  }
  "s940-westeurope-diagnostics" = {
    name             = "s940-westeurope-diagnostics"
    rg_name          = "logs-westeurope"
    managed_identity = true
  }
}


#######################################################################################
### Logic Apps
###

logic_app_workflow = {
  "archive-s940-northeurope-diagnostics" = {
    name                  = "archive-s940-northeurope-diagnostics"
    rg_name               = "Logs"
    managed_identity_name = "id-radix-logicapp-operator-prod"
    loganalytics          = "s940-northeurope-diagnostics"
    storageaccount        = "radixflowlogsprod"
    folder                = "prod"
  }
  "archive-s940-westeurope-diagnostics" = {
    name                  = "archive-s940-westeurope-diagnostics"
    location              = "westeurope"
    rg_name               = "logs-westeurope"
    managed_identity_name = "id-radix-logicapp-operator-c2"
    loganalytics          = "s940-westeurope-diagnostics"
    storageaccount        = "radixflowlogsc2prod"
    folder                = "c2"
  }
}


#######################################################################################
### Resouce Groups
###

resource_groups = {
  "backups" = {
    name = "backups"
  }
  "clusters" = {
    name = "clusters"
  }
  "cluster-vnet-hub-c2" = {
    name     = "cluster-vnet-hub-c2"
    location = "westeurope"
  }
  "cluster-vnet-hub-prod" = {
    name = "cluster-vnet-hub-prod"
  }
  "common" = {
    name = "common"
  }
  "cost-allocation" = {
    name = "cost-allocation"
  }
  "dashboards" = {
    name     = "dashboards"
    location = "westeurope"
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

aks_clouster_resource_groups = ["clusters-westeurope", "clusters"]

#######################################################################################
### Storage Accounts
###

storage_accounts = {
  "radixflowlogsc2prod" = {
    name                 = "radixflowlogsc2prod"
    rg_name              = "logs-westeurope"
    location             = "westeurope"
    backup_center        = true
    life_cycle           = false
    managed_identity     = true
    life_cycle           = true
    life_cycle_version   = 3
    life_cycle_blob      = 90
    life_cycle_blob_cool = 7
  }
  "radixflowlogsprod" = {
    name                 = "radixflowlogsprod"
    rg_name              = "Logs"
    backup_center        = true
    life_cycle           = false
    managed_identity     = true
    life_cycle           = true
    life_cycle_version   = 3
    life_cycle_blob      = 90
    life_cycle_blob_cool = 7
  }
  "s940radixinfra" = {
    name             = "s940radixinfra"
    rg_name          = "s940-tfstate"
    repl             = "RAGRS"
    life_cycle       = true
    backup_center    = true
    firewall         = false
    create_with_rbac = true
    life_cycle_blob  = 0
  }
  "s940radixveleroc2" = {
    name             = "s940radixveleroc2"
    rg_name          = "backups"
    location         = "westeurope"
    repl             = "GRS"
    backup_center    = true
    private_endpoint = true
  }
  "s940radixveleroprod" = {
    name             = "s940radixveleroprod"
    rg_name          = "backups"
    repl             = "GRS"
    backup_center    = true
    private_endpoint = true
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
    name     = "sql-radix-cost-allocation-c2-prod"
    rg_name  = "cost-allocation-westeurope"
    location = "westeurope"
    db_admin = "radix-cost-allocation-db-admin"
    vault    = "radix-vault-c2-prod"
    env      = "c2"
    tags = {
      "displayName" = "SqlServer"
    }
    identity = false
  }
  "sql-radix-cost-allocation-prod" = {
    name     = "sql-radix-cost-allocation-prod"
    rg_name  = "cost-allocation"
    db_admin = "radix-cost-allocation-db-admin"
    vault    = "radix-vault-prod"
    env      = "prod"
    sku_name = "S3"
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
    vault    = "radix-vault-c2-prod"
    env      = "c2"
  }
  "sql-radix-vulnerability-scan-prod" = {
    name     = "sql-radix-vulnerability-scan-prod"
    rg_name  = "vulnerability-scan"
    db_admin = "radix-vulnerability-scan-db-admin"
    vault    = "radix-vault-prod"
    env      = "prod"
    sku_name = "S3"
  }
}

#######################################################################################
### SQL Database
###

sql_database = {
  "sql-radix-cost-allocation-c2-prod" = {
    name   = "sqldb-radix-cost-allocation"
    server = "sql-radix-cost-allocation-c2-prod"
    tags = {
      "displayName" = "Database"
    }
  }
  "sql-radix-cost-allocation-prod" = {
    name     = "sqldb-radix-cost-allocation"
    server   = "sql-radix-cost-allocation-prod"
    sku_name = "S3"
    tags = {
      "displayName" = "Database"
    }
  }
  "sql-radix-vulnerability-scan-c2-prod" = {
    name   = "radix-vulnerability-scan"
    server = "sql-radix-vulnerability-scan-c2-prod"
  }
  "sql-radix-vulnerability-scan-prod" = {
    name     = "radix-vulnerability-scan"
    server   = "sql-radix-vulnerability-scan-prod"
    sku_name = "S3"
  }
}

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

#######################################################################################
### Key Vault
###

key_vault = {
  "kv-radix-monitoring-prod" = {
    name    = "kv-radix-monitoring-prod"
    rg_name = "monitoring"
  }
  "radix-vault-c2-prod" = {
    name    = "radix-vault-c2-prod"
    rg_name = "common-westeurope"
  }
  "radix-vault-prod" = {
    name    = "radix-vault-prod"
    rg_name = "common"
  }
}

key_vault_by_k8s_environment = {
  "prod" = {
    name    = "radix-vault-prod"
    rg_name = "common"
  }
  "c2" = {
    name    = "radix-vault-c2-prod"
    rg_name = "common-westeurope"
  }
  "monitoring" = {
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

EQUINOR_WIFI_IP_CIDR = "143.97.110.1/32"

KV_RADIX_VAULT = "radix-vault-prod"

private_link = {
  "c2" = {
    linkname = "/subscriptions/ded7ca41-37c8-4085-862f-b11d21ab341a/resourceGroups/cluster-vnet-hub-c2/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/private-links"
  }
  "prod" = {
    linkname = "/subscriptions/ded7ca41-37c8-4085-862f-b11d21ab341a/resourceGroups/cluster-vnet-hub-prod/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/private-links"
  }
}

#######################################################################################
### Virtual network
###

virtual_networks = {
  "c2" = {
    rg_name = "cluster-vnet-hub-c2"
  }
  "prod" = {
    rg_name = "cluster-vnet-hub-prod"
  }
}

#######################################################################################
### Service principal
###

APP_GITHUB_ACTION_CLUSTER_NAME = "OP-Terraform-Github Action"

#######################################################################################
### Github
###

GH_ORGANIZATION = "equinor"
GH_REPOSITORY   = "radix-platform"
GH_ENVIRONMENT  = "operations"

# Update this and run terraform in acr to rotate secrets.
# Remember to restart Operator afterwards to get refreshed tokens
ACR_TOKEN_EXPIRES_AT = "2024-11-01T12:00:00+00:00"
