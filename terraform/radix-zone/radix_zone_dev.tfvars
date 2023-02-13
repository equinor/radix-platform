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
AZ_TENANT_ID       = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"

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
### Key Vault
###

key_vault = {
  "cadb-admin-dev" = {
    name = "radix-cost-allocation-db-admin"
  }
  "cadb-admin-playground" = {
    name = "radix-cost-allocation-db-admin-playground"
  }
  "vs-db-admin-dev" = {
    name = "radix-vulnerability-scan-db-admin"
  }
  "vs-db-admin-playground" = {
    name = "radix-vulnerability-scan-db-admin-playground"
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

#######################################################################################
### Service principal
###

SP_GITHUB_DEV_CLUSTER_CLIENT_ID = "f1e6bc52-9aa4-4ca7-a9ac-b7a19d8f0f86"

#######################################################################################
### Keyvaults
###

KV_RADIX_VAULT_DEV = "radix-vault-dev"
