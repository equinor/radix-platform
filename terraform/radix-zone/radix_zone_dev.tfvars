#######################################################################################
### Zone and cluster settings
###

AZ_LOCATION = "northeurope"
RADIX_ZONE  = "dev"
K8S_ENVIROMENTS = {
  "dev"        = { "name" = "dev", "resourceGroup" = "clusters" },
  "playground" = { "name" = "playground", "resourceGroup" = "clusters" }
}

#######################################################################################
### Resource groups
###

AZ_RESOURCE_GROUP_COMMON = "common"

#######################################################################################
### Shared environment, az region and az subscription
###

AZ_SUBSCRIPTION_ID        = "16ede44b-1f74-40a5-b428-46cca9a5741b"
AZ_TENANT_ID              = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
AZ_SUBSCRIPTION_SHORTNAME = "s941"

#######################################################################################
### AAD
###

AAD_RADIX_GROUP = "radix"

#######################################################################################
### Managed Identities
###

managed_identity = {
  "id-radix-logicapp-operator-dev" = {
    name    = "id-radix-logicapp-operator-dev"
    rg_name = "Logs-Dev"
  }
}

#######################################################################################
### Log Analytics
###

loganalytics = {
  "s941-northeurope-diagnostics" = {
    name             = "s941-northeurope-diagnostics"
    rg_name          = "Logs-dev"
    managed_identity = true
  }
}

#######################################################################################
### Logic Apps
###

logic_app_workflow = {
  "archive-s941-northeurope-diagnostics" = {
    name                  = "archive-s941-northeurope-diagnostics"
    rg_name               = "Logs-Dev"
    managed_identity_name = "id-radix-logicapp-operator-dev"
    loganalytics          = "s941-northeurope-diagnostics"
    storageaccount        = "radixflowlogsplayground"
    folder                = "playground"
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
  "cluster-vnet-hub-dev" = {
    name = "cluster-vnet-hub-dev"
  }
  "cluster-vnet-hub-playground" = {
    name = "cluster-vnet-hub-playground"
  }
  "common" = {
    name = "common"
  }
  "cost-allocation" = {
    name = "cost-allocation"
  }
  "dashboards" = {
    name = "dashboards"
  }
  "monitoring" = {
    name = "monitoring"
  }
  "S941-log" = {
    name     = "S941-log"
    location = "westeurope"
  }
  "s941-tfstate" = {
    name = "s941-tfstate"
  }
  "Logs-Dev" = {
    name = "Logs-Dev"
  }
  "vulnerability-scan" = {
    name = "vulnerability-scan"
  }
}

aks_clouster_resource_groups = ["clusters"]

#######################################################################################
### Storage Accounts
###

storage_accounts = {
  "radixflowlogsdev" = {
    name          = "radixflowlogsdev"
    rg_name       = "Logs-Dev"
    backup_center = true
  }
  "radixflowlogsplayground" = {
    name                 = "radixflowlogsplayground"
    rg_name              = "Logs-Dev"
    backup_center        = true
    managed_identity     = true
    life_cycle           = true
    life_cycle_version   = 3
    life_cycle_blob      = 90
    life_cycle_blob_cool = 7
  }
  "s941radixinfra" = {
    name                            = "s941radixinfra"
    rg_name                         = "s941-tfstate"
    backup_center                   = true
    life_cycle                      = false
    repl                            = "RAGRS"
    allow_nested_items_to_be_public = false
    create_with_rbac                = true
    firewall                        = false
  }
  "s941radixvelerodev" = {
    name                            = "s941radixvelerodev"
    rg_name                         = "backups"
    backup_center                   = true
    repl                            = "GRS"
    allow_nested_items_to_be_public = false
    firewall                        = true
    private_endpoint                = true

  }
  "s941sqllogsdev" = {
    name          = "s941sqllogsdev"
    rg_name       = "common"
    backup_center = true
  }
  "s941sqllogsplayground" = {
    name          = "s941sqllogsplayground"
    rg_name       = "common"
    backup_center = true
  }
}

#######################################################################################
### SQL Server
###

sql_server = {
  "sql-radix-cost-allocation-dev" = {
    name     = "sql-radix-cost-allocation-dev"
    rg_name  = "cost-allocation"
    db_admin = "radix-cost-allocation-db-admin"
    vault    = "radix-vault-dev"
    env      = "dev"
    tags = {
      "displayName" = "SqlServer"
    }
  }
  "sql-radix-cost-allocation-playground" = {
    name     = "sql-radix-cost-allocation-playground"
    rg_name  = "cost-allocation"
    db_admin = "radix-cost-allocation-db-admin-playground"
    vault    = "radix-vault-dev"
    env      = "playground"
    tags = {
      "displayName" = "SqlServer"
    }
  }
  "sql-radix-vulnerability-scan-dev" = {
    name     = "sql-radix-vulnerability-scan-dev"
    rg_name  = "vulnerability-scan"
    db_admin = "radix-vulnerability-scan-db-admin"
    identity = true
    vault    = "radix-vault-dev"
    env      = "dev"
  }
  "sql-radix-vulnerability-scan-playground" = {
    name     = "sql-radix-vulnerability-scan-playground"
    rg_name  = "vulnerability-scan"
    db_admin = "radix-vulnerability-scan-db-admin-playground"
    identity = false
    vault    = "radix-vault-dev"
    env      = "playground"
  }
}

#######################################################################################
### SQL Database
###

sql_database = {
  "sql-radix-cost-allocation-dev" = {
    name   = "sqldb-radix-cost-allocation"
    server = "sql-radix-cost-allocation-dev"
    tags = {
      "displayName" = "Database"
    }
  }
  "sql-radix-cost-allocation-playground" = {
    name   = "sqldb-radix-cost-allocation"
    server = "sql-radix-cost-allocation-playground"
    tags = {
      "displayName" = "Database"
    }
  }
  "sql-radix-vulnerability-scan-dev" = {
    name   = "radix-vulnerability-scan"
    server = "sql-radix-vulnerability-scan-dev"
  }
  "sql-radix-vulnerability-scan-playground" = {
    name   = "radix-vulnerability-scan"
    server = "sql-radix-vulnerability-scan-playground"
  }
}

#######################################################################################
### MYSQL Flexible Server
###

mysql_flexible_server = {
  "s941-radix-grafana-dev" = {
    name   = "s941-radix-grafana-dev"
    secret = "s941-radix-grafana-dev-mysql-admin-pwd"
  }
  "s941-radix-grafana-playground" = {
    name   = "s941-radix-grafana-playground"
    secret = "s941-radix-grafana-playground-mysql-admin-pwd"
  }
}

#######################################################################################
### MYSQL Server
###

mysql_server = {
  "mysql-radix-grafana-dev" = {
    name    = "mysql-radix-grafana-dev"
    fw_rule = true
    secret  = "mysql-grafana-dev-admin-password"
  }
}

#######################################################################################
### Key Vault
###

key_vault = {
  "kv-radix-monitoring-dev" = {
    name    = "kv-radix-monitoring-dev"
    rg_name = "monitoring"
  }
  "radix-vault-dev" = {
    name    = "radix-vault-dev"
    rg_name = "common"
  }
}

key_vault_by_k8s_environment = {
  "dev" = {
    name    = "radix-vault-dev"
    rg_name = "common"
  }
  "playground" = {
    name    = "radix-vault-dev"
    rg_name = "common"
  }
  "monitoring" = {
    name    = "kv-radix-monitoring-dev"
    rg_name = "monitoring"
  }
}

firewall_rules = {
  "equinor-wifi" = {
    start_ip_address = "143.97.110.1"
    end_ip_address   = "143.97.110.1"
  }
  "equinor_north_europe" = {
    start_ip_address = "40.85.141.13"
    end_ip_address   = "40.85.141.13"
  }
  "ext-mon-dev" = {
    start_ip_address = "20.54.47.154"
    end_ip_address   = "20.54.47.154"
  }
  "runnerIp" = {
    start_ip_address = "20.36.193.46"
    end_ip_address   = "20.36.193.46"
  }
  "weekly-42-b" = {
    start_ip_address = "20.67.128.243"
    end_ip_address   = "20.67.128.243"
  }
  "Enable-Azure-services" = {
    start_ip_address = "0.0.0.0"
    end_ip_address   = "0.0.0.0"
  }
}

EQUINOR_WIFI_IP_CIDR = "143.97.110.1/32"

KV_RADIX_VAULT = "radix-vault-dev"

private_link = {
  "dev" = {
    linkname = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/cluster-vnet-hub-dev/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/private-links"
  }
  "playground" = {
    linkname = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/cluster-vnet-hub-playground/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/private-links"
  }
}

#######################################################################################
### Virtual network
###

virtual_networks = {
  "dev" = {
    rg_name = "cluster-vnet-hub-dev"
  }
  "playground" = {
    rg_name = "cluster-vnet-hub-playground"
  }
}

#######################################################################################
### Service principal
###

APP_GITHUB_ACTION_CLUSTER_NAME     = "ar-radix-platform-github-dev-cluster-maintenance"
SP_GITHUB_ACTION_CLUSTER_CLIENT_ID = "f1e6bc52-9aa4-4ca7-a9ac-b7a19d8f0f86"

#######################################################################################
### Github
###

GH_ORGANIZATION = "equinor"
GH_REPOSITORY   = "radix-platform"
GH_ENVIRONMENT  = "operations"

# Update this and run terraform in acr to rotate secrets.
# Remember to restart Operator afterwards to get refreshed tokens
ACR_TOKEN_EXPIRES_AT = "2024-11-01T12:00:00+00:00"
