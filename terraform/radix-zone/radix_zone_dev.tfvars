#######################################################################################
### AKS
###

AKS_KUBERNETES_VERSION    = "1.23.12"
AKS_NODE_POOL_VM_SIZE     = "Standard_B4ms"
AKS_SYSTEM_NODE_MAX_COUNT = "2"
AKS_SYSTEM_NODE_MIN_COUNT = "1"
AKS_SYSTEM_NODE_POOL_NAME = "systempool"
AKS_USER_NODE_MAX_COUNT   = "5"
AKS_USER_NODE_MIN_COUNT   = "2"
AKS_USER_NODE_POOL_NAME   = "userpool"
TAGS                      = { "autostartupschedule " = "true" }

#######################################################################################
### Zone and cluster settings
###

AZ_LOCATION                    = "northeurope"
CLUSTER_TYPE                   = "development"
RADIX_ZONE                     = "dev"
RADIX_ENVIRONMENT              = "dev"
RADIX_WEB_CONSOLE_ENVIRONMENTS = ["qa", "prod"]

#######################################################################################
### Resource groups
###

AZ_RESOURCE_GROUP_CLUSTERS = "clusters"
AZ_RESOURCE_GROUP_COMMON   = "common"

#######################################################################################
### Shared environment, az region and az subscription
###

AZ_SUBSCRIPTION_ID = "16ede44b-1f74-40a5-b428-46cca9a5741b"

#######################################################################################
### System users
###

MI_AKSKUBELET = [{
  client_id = "117df4c6-ff5b-4921-9c40-5bea2e1c52d8"
  id        = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/common/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-radix-akskubelet-development-northeurope"
  object_id = "89541870-e10a-403c-8d4c-d80e92dd5eb7"
}]
MI_AKS = [{
  client_id = "1ff97b0f-f824-47d9-a98f-a045b6a759bc"
  id        = "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/common/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-radix-aks-development-northeurope",
  object_id = "7112e202-51f7-4fd2-b6a1-b944f14f0be3"
}]

AZ_PRIVATE_DNS_ZONES = [
  "privatelink.database.windows.net",
  "privatelink.blob.core.windows.net",
  "privatelink.table.core.windows.net",
  "privatelink.queue.core.windows.net",
  "privatelink.file.core.windows.net",
  "privatelink.web.core.windows.net",
  "privatelink.dfs.core.windows.net",
  "privatelink.documents.azure.com",
  "privatelink.mongo.cosmos.azure.com",
  "privatelink.cassandra.cosmos.azure.com",
  "privatelink.gremlin.cosmos.azure.com",
  "privatelink.table.cosmos.azure.com",
  "privatelink.postgres.database.azure.com",
  "privatelink.mysql.database.azure.com",
  "privatelink.mariadb.database.azure.com",
  "privatelink.vaultcore.azure.net",
  "private.radix.equinor.com"
]

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

#######################################################################################
### Storage Accounts
###

storage_accounts = {
  "radixflowlogsdev" = {
    name          = "radixflowlogsdev"
    rg_name       = "Logs-Dev"
    backup_center = true
  }
  "radixinfradev" = {
    name                      = "radixinfradev"
    rg_name                   = "s941-tfstate"
    backup_center             = false
    repl                      = "GRS"
    kind                      = "BlobStorage"
    shared_access_key_enabled = false
    firewall                  = false
  }
  "radixvelerodev" = {
    name          = "radixvelerodev"
    rg_name       = "backups"
    backup_center = false
    repl          = "GRS"
    kind          = "BlobStorage"
  }
  "s941radixinfra" = {
    name                            = "s941radixinfra"
    rg_name                         = "s941-tfstate"
    backup_center                   = true
    repl                            = "RAGRS"
    allow_nested_items_to_be_public = false
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
    name                = "sql-radix-cost-allocation-dev"
    rg_name             = "cost-allocation"
    db_admin            = "radix-cost-allocation-db-admin"
    minimum_tls_version = "Disabled"
    tags = {
      "displayName" = "SqlServer"
    }
  }
  "sql-radix-cost-allocation-playground" = {
    name                = "sql-radix-cost-allocation-playground"
    rg_name             = "cost-allocation"
    db_admin            = "radix-cost-allocation-db-admin-playground"
    minimum_tls_version = "Disabled"
    tags = {
      "displayName" = "SqlServer"
    }
  }
  "sql-radix-vulnerability-scan-dev" = {
    name     = "sql-radix-vulnerability-scan-dev"
    rg_name  = "vulnerability-scan"
    db_admin = "radix-vulnerability-scan-db-admin"
    identity = false
  }
  "sql-radix-vulnerability-scan-playground" = {
    name     = "sql-radix-vulnerability-scan-playground"
    rg_name  = "vulnerability-scan"
    db_admin = "radix-vulnerability-scan-db-admin-playground"
    identity = false
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
    name  = "s941-radix-grafana-dev"
    fw_rule = false
    fw_secret = "S941-radix-grafana-dev-admin-password"
  }
#  "s941-radix-grafana-playground" = {
#     name  = "s941-radix-grafana-playground"
#     fw_rule = false
#     fw_secret = "S941-radix-grafana-playground-admin-password"
#   }

}

#######################################################################################
### MYSQL Server
###

mysql_server = {
  "mysql-radix-grafana-dev" = {
    name  = "mysql-radix-grafana-dev"
    fw_rule = true
    fw_secret = "mysql-radix-grafana-dev-ip"
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
  # "cadb-admin-dev" = {
  #   name = "radix-cost-allocation-db-admin"
  # }
  # "cadb-admin-playground" = {
  #   name = "radix-cost-allocation-db-admin-playsS941_radixground"
  # }
  # "vs-db-admin-dev" = {
  #   name = "radix-vulnerability-scan-db-admin"
  # }
  # "vs-db-admin-playground" = {sS941_radix
  #   name = "radix-vulnerability-scan-db-admin-playground"
  # }
}

key_secrets = {
  "mysql-radix-grafana-dev" = {
    name  = "grafana-database-password"
    vault = "kv-radix-monitoring-dev"
  }
  "mysql-radix-grafana-dev-ip" = {
    name  = "mysql-radix-grafana-dev-ip"
    vault = "kv-radix-monitoring-dev"
  }
  "s941-radix-grafana-dev" = {
    name  = "S941-radix-grafana-dev-admin-password"
    vault = "kv-radix-monitoring-dev"
  }
  "s941-radix-grafana-playground" = {
    name  = "S941-radix-grafana-playground-admin-password"
    vault = "kv-radix-monitoring-dev"
  }
}


firewall_rules = {
  "equinor-wifi" = {
    start_ip_address = "143.97.110.1"
    end_ip_address = "143.97.110.1"
  }
  "equinor_north_europe" = {
    start_ip_address = "40.85.141.13"
    end_ip_address = "40.85.141.13"
  }
  "ext-mon-dev" = {
    start_ip_address = "20.54.47.154"
    end_ip_address = "20.54.47.154"
  }
  "runnerIp" = {
    start_ip_address = "20.36.193.46"
    end_ip_address = "20.36.193.46"
  }
  "weekly-42-b" = {
    start_ip_address = "20.67.128.243"
    end_ip_address = "20.67.128.243"
  }
  "Enable-Azure-services" = {
    start_ip_address = "0.0.0.0"
    end_ip_address = "0.0.0.0"
  }


}
#######################################################################################
### Virtual networks
###

vnets = {
  "vnet-playground-07" = {
    vnet_name   = "vnet-playground-07"
    subnet_name = "subnet-playground-07"
  }
  "vnet-weekly-03" = {
    vnet_name   = "vnet-weekly-03"
    subnet_name = "subnet-weekly-03"
  }
  "vnet-weekly-04" = {
    vnet_name   = "vnet-weekly-04"
    subnet_name = "subnet-weekly-04"
  }
}
