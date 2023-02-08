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
