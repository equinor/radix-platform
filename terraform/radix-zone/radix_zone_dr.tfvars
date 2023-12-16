#######################################################################################
### AKS
###

AKS_KUBERNETES_VERSION    = "1.26.6"
AKS_NODE_POOL_VM_SIZE     = "Standard_B4ms"
AKS_SYSTEM_NODE_MAX_COUNT = "2"
AKS_SYSTEM_NODE_MIN_COUNT = "1"
AKS_SYSTEM_NODE_POOL_NAME = "systempool"
AKS_USER_NODE_MAX_COUNT   = "5"
AKS_USER_NODE_MIN_COUNT   = "2"
AKS_USER_NODE_POOL_NAME   = "userpool"
TAGS_AA                   = { "autostartupschedule " = "true", "migrationStrategy" = "aa" }
TAGS_AT                   = { "autostartupschedule " = "false", "migrationStrategy" = "at" }

#######################################################################################
### Zone and cluster settings
###

AZ_LOCATION                    = "northeurope"
CLUSTER_TYPE                   = "development"
RADIX_ZONE                     = "dev"
RADIX_ENVIRONMENT              = "dev"
RADIX_WEB_CONSOLE_ENVIRONMENTS = ["qa", "prod"]
K8S_ENVIROMENTS                = ["dev"]
# K8S_ENVIROMENTS                = ["dev", "playground"]

#######################################################################################
### Resource groups
###

AZ_RESOURCE_GROUP_CLUSTERS = "clusters"
AZ_RESOURCE_GROUP_COMMON   = "common"

#######################################################################################
### Shared environment, az region and az subscription
###

AZ_SUBSCRIPTION_ID        = "939950ec-da7e-4349-8b8d-77d9c278af04"
AZ_TENANT_ID              = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
AZ_SUBSCRIPTION_SHORTNAME = "s612"

#######################################################################################
### AAD
###

AAD_RADIX_GROUP = "radix"

#######################################################################################
### System users
###

MI_AKSKUBELET = [{
  client_id = "117df4c6-ff5b-4921-9c40-5bea2e1c52d8"
  id        = "/subscriptions/939950ec-da7e-4349-8b8d-77d9c278af04/resourceGroups/common/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-radix-akskubelet-development-northeurope"
  object_id = "89541870-e10a-403c-8d4c-d80e92dd5eb7"
}]

MI_AKS = [{
  client_id = "1ff97b0f-f824-47d9-a98f-a045b6a759bc"
  id        = "/subscriptions/939950ec-da7e-4349-8b8d-77d9c278af04/resourceGroups/common/providers/Microsoft.ManagedIdentity/userAssignedIdentities/id-radix-aks-development-northeurope",
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

#To do
#Alphabetical order
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
  "s612-northeurope-diagnostics" = {
    name             = "s612-northeurope-diagnostics"
    rg_name          = "Logs-dev"
    managed_identity = true
  }
}

#######################################################################################
### Logic Apps
###

logic_app_workflow = {
  "archive-s612-northeurope-diagnostics" = {
    name                  = "archive-s612-northeurope-diagnostics"
    rg_name               = "Logs-Dev"
    managed_identity_name = "id-radix-logicapp-operator-dev"
    loganalytics          = "s612-northeurope-diagnostics"
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
  # "cluster-vnet-hub-playground" = {
  #   name = "cluster-vnet-hub-playground"
  # }
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
  "s612-log" = {
    name     = "s612-log"
    location = "westeurope"
  }
  "s612-tfstate" = {
    name = "s612-tfstate"
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
  "radixflowlogsdevdr" = {
    name          = "radixflowlogsdevdr"
    rg_name       = "Logs-Dev"
    backup_center = true
  }
  # "radixflowlogsplayground" = {
  #   name             = "radixflowlogsplayground"
  #   rg_name          = "Logs-Dev"
  #   backup_center    = true
  #   managed_identity = true
  # }
  "s612radixinfra" = {
    name                            = "s612radixinfra"
    rg_name                         = "s612-tfstate"
    backup_center                   = true
    repl                            = "RAGRS"
    allow_nested_items_to_be_public = false
    create_with_rbac                = true
    firewall                        = false
  }
  "s612radixvelerodev" = {
    name                            = "s612radixvelerodev"
    rg_name                         = "backups"
    backup_center                   = true
    repl                            = "GRS"
    allow_nested_items_to_be_public = false
    firewall                        = true
    private_endpoint                = true

  }
  "s612sqllogsdev" = {
    name          = "s612sqllogsdev"
    rg_name       = "common"
    backup_center = true
  }
  # "s612sqllogsplayground" = {
  #   name          = "s612sqllogsplayground"
  #   rg_name       = "common"
  #   backup_center = true
  # }
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
    vault               = "radix-vault-dev-dr2"
    tags = {
      "displayName" = "SqlServer"
    }
  }
  # "sql-radix-cost-allocation-playground" = {
  #   name                = "sql-radix-cost-allocation-playground"
  #   rg_name             = "cost-allocation"
  #   db_admin            = "radix-cost-allocation-db-admin-playground"
  #   minimum_tls_version = "Disabled"
  #   vault               = "radix-vault-dev-dr2"
  #   tags = {
  #     "displayName" = "SqlServer"
  #   }
  # }
  "sql-radix-vulnerability-scan-dev" = {
    name     = "sql-radix-vulnerability-scan-dev"
    rg_name  = "vulnerability-scan"
    db_admin = "radix-vulnerability-scan-db-admin"
    identity = false
    vault    = "radix-vault-dev-dr2"
  }
  # "sql-radix-vulnerability-scan-playground" = {
  #   name     = "sql-radix-vulnerability-scan-playground"
  #   rg_name  = "vulnerability-scan"
  #   db_admin = "radix-vulnerability-scan-db-admin-playground"
  #   identity = false
  #   vault    = "radix-vault-dev-dr2"
  # }
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
  # "sql-radix-cost-allocation-playground" = {
  #   name   = "sqldb-radix-cost-allocation"
  #   server = "sql-radix-cost-allocation-playground"
  #   tags = {
  #     "displayName" = "Database"
  #   }
  # }
  "sql-radix-vulnerability-scan-dev" = {
    name   = "radix-vulnerability-scan"
    server = "sql-radix-vulnerability-scan-dev"
  }
  # "sql-radix-vulnerability-scan-playground" = {
  #   name   = "radix-vulnerability-scan"
  #   server = "sql-radix-vulnerability-scan-playground"
  # }
}

#######################################################################################
### MYSQL Flexible Server
###

mysql_flexible_server = {
  "s612-radix-grafana-dev" = {
    name   = "s612-radix-grafana-dev"
    secret = "s612-radix-grafana-dev-mysql-admin-pwd"
  }
  # "s612-radix-grafana-playground" = {
  #   name   = "s612-radix-grafana-playground"
  #   secret = "s612-radix-grafana-playground-mysql-admin-pwd"
  # }
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
  "radix-vault-dev-dr2" = {
    name    = "radix-vault-dev-dr2"
    rg_name = "common"
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

KV_RADIX_VAULT = "radix-vault-dev-dr2"

private_link = {
  "dev" = {
    linkname = "/subscriptions/939950ec-da7e-4349-8b8d-77d9c278af04/resourceGroups/cluster-vnet-hub-dev/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/private-links"
  }
  # "playground" = {
  #   linkname = "/subscriptions/939950ec-da7e-4349-8b8d-77d9c278af04/resourceGroups/cluster-vnet-hub-playground/providers/Microsoft.Network/virtualNetworks/vnet-hub/subnets/private-links"
  # }
}

#######################################################################################
### Virtual network
###

virtual_networks = {
  "dev" = {
    rg_name = "cluster-vnet-hub-dev"
  }
  # "playground" = {
  #   rg_name = "cluster-vnet-hub-playground"
  # }
}

#######################################################################################
### Service principal
###

APP_GITHUB_ACTION_CLUSTER_NAME     = "ar-radix-platform-github-dev-cluster-maintenance-dr"

#######################################################################################
### Github
###

GH_ORGANIZATION = "equinor"
GH_REPOSITORY   = "radix-platform"
GH_ENVIRONMENT  = "operations-dr"
