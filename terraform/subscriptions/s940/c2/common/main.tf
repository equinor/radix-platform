module "config" {
  source = "../../../modules/config"
}

module "resourcegroups" {
  source   = "../../../modules/resourcegroups"
  name     = module.config.common_resource_group
  location = module.config.location
}

module "backupvault" {
  source                = "../../../modules/backupvaults"
  name                  = "Backupvault-${module.config.environment}"
  resource_group_name   = "common-${module.config.environment}"
  location              = module.config.location
  policyblobstoragename = "Backuppolicy-blob"
  depends_on            = [module.resourcegroups]
}

module "loganalytics" {
  source                        = "../../../modules/log-analytics"
  workspace_name                = "radix-logs-${module.config.environment}"
  resource_group_name           = "common-${module.config.environment}"
  location                      = module.config.location
  retention_in_days             = 30
  local_authentication_disabled = false
}

data "azurerm_resource_group" "logs" {
  name = "Logs-${module.config.location}"
}

data "azurerm_resource_group" "clusters" {
  name = "clusters-${module.config.environment}"
}

data "azurerm_resource_group" "networkwatcher" {
  name = "NetworkWatcherRG"
}

data "azurerm_key_vault" "this" {
  name                = "radix-keyv-${module.config.environment}"
  resource_group_name = "common-${module.config.environment}"
}

data "azurerm_virtual_network" "this" {
  name                = "vnet-hub"
  resource_group_name = module.config.vnet_resource_group
}

data "azurerm_subnet" "this" {
  name                 = "private-links"
  resource_group_name  = module.config.vnet_resource_group
  virtual_network_name = data.azurerm_virtual_network.this.name
}

module "storageaccount" {
  source                    = "../../../modules/storageaccount"
  for_each                  = var.storageaccounts
  name                      = "radix${each.key}${module.config.environment}"
  tier                      = each.value.account_tier
  account_replication_type  = each.value.account_replication_type
  resource_group_name       = each.value.resource_group_name
  location                  = each.value.location
  environment               = module.config.environment
  kind                      = each.value.kind
  change_feed_enabled       = each.value.change_feed_enabled
  versioning_enabled        = each.value.versioning_enabled
  backup                    = each.value.backup
  principal_id              = module.backupvault.data.backupvault.identity[0].principal_id
  vault_id                  = module.backupvault.data.backupvault.id
  policyblobstorage_id      = module.backupvault.data.policyblobstorage.id
  subnet_id                 = data.azurerm_subnet.this.id
  vnet_resource_group       = module.config.vnet_resource_group
  lifecyclepolicy           = each.value.lifecyclepolicy
  ip_rule                   = data.azurerm_key_vault_secret.this.value
  log_analytics_id          = module.loganalytics.workspace_id
  shared_access_key_enabled = each.value.shared_access_key_enabled #Needed in module create container when running apply
}

module "acr" {
  source               = "../../../modules/acr"
  ip_rule              = data.azurerm_key_vault_secret.this.value
  location             = module.config.location
  resource_group_name  = "common" #TODO
  acr                  = module.config.environment
  common_res_group     = module.config.common_resource_group
  vnet_resource_group  = module.config.vnet_resource_group
  subnet_id            = data.azurerm_subnet.this.id
  dockercredentials_id = "/subscriptions/${module.config.subscription}/resourceGroups/${module.config.common_resource_group}/providers/Microsoft.ContainerRegistry/registries/radix${module.config.environment}cache/credentialSets/radix-service-account-docker"
  radix_cr_cicd        = replace(replace(module.app_application_registration.cr_cicd.azuread_service_principal_id, "/servicePrincipals/", ""), "/", "")
}

module "radix-id-acr-workflows" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-acr-workflows-${module.config.environment}"
  resource_group_name = module.config.common_resource_group
  location            = module.config.location
  roleassignments = {
    contributor = {
      role     = "Contributor" # Needed to open firewall
      scope_id = module.acr.azurerm_container_registry_id
    },
    acrpush = {
      role     = "AcrPush"
      scope_id = module.acr.azurerm_container_registry_id
    }
  }
  federated_credentials = {
    radix-acr-cleanup-release = {
      name    = "radix-acr-cleanup-release"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-acr-cleanup:ref:refs/heads/release"
    },
    radix-cluster-cleanup-release = {
      name    = "radix-cluster-cleanup-release"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-cluster-cleanup:ref:refs/heads/release"
    },
    radix-cicd-canary-release = {
      name    = "radix-cicd-canary-release"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-cicd-canary:ref:refs/heads/release"
    },
    radix-vulnerability-scanner-release = {
      name    = "radix-vulnerability-scanner-release"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-vulnerability-scanner:ref:refs/heads/release"
    },
    radix-image-builder-release = {
      name    = "radix-image-builder-release"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-image-builder:ref:refs/heads/release"
    },
    radix-tekton-release = {
      name    = "radix-tekton-release"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-tekton:ref:refs/heads/release"
    },
    radix-operator-master = {
      name    = "radix-operator-master"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-operator:ref:refs/heads/master"
    },
    radix-operator-release = {
      name    = "radix-operator-release"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-operator:ref:refs/heads/release"
    },
    radix-velero-plugin-release = {
      name    = "radix-velero-plugin-release"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-velero-plugin:ref:refs/heads/release"
    },
    radix-job-scheduler-release = {
      name    = "radix-job-scheduler-release"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-job-scheduler:ref:refs/heads/release"
    },
    radix-buildkit-builder-release = {
      name    = "radix-buildkit-builder-release"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-buildkit-builder:ref:refs/heads/release"
    },
  }
}

module "radix_id_gitrunner" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-gitrunner-${module.config.environment}"
  resource_group_name = module.config.common_resource_group
  location            = module.config.location
  roleassignments = {
    privatelink-contributor = {
      role     = "Radix Privatelink rbac-${module.config.subscription_shortname}"
      scope_id = "/subscriptions/${module.config.subscription}"
    }
    blob_contributor = {
      role     = "Contributor" # Needed to open firewall
      scope_id = "${module.config.backend.terraform_storage_id}"
    }
    storage_blob_contributor = {
      role     = "Storage Blob Data Contributor" # Needed to read blobdata
      scope_id = "${module.config.backend.terraform_storage_id}"
    }
    common_contributor = {
      role     = "Contributor" # Needed to open firewall
      scope_id = "${module.resourcegroups.data.id}"
    }
    logs_contributor = {
      role     = "Contributor"
      scope_id = "${data.azurerm_resource_group.logs.id}"
    }
    clusters_contributor = {
      role     = "Contributor"
      scope_id = "${data.azurerm_resource_group.clusters.id}"
    }
    networkwatcher_contributor = {
      role     = "Contributor"
      scope_id = "${data.azurerm_resource_group.networkwatcher.id}"
    }
    keyvault_contributor = {
      role     = "Key Vault Secrets User" # Needed to read secrets
      scope_id = "${data.azurerm_key_vault.this.id}"
    }
    vnet_contributor = {
      role     = "Contributor"
      scope_id = "/subscriptions/${module.config.subscription}/resourceGroups/${data.azurerm_virtual_network.this.resource_group_name}"
    }
    app_registry_contributor = {
      role     = "Contributor"
      scope_id = "/subscriptions/${module.config.subscription}/resourceGroups/common/providers/Microsoft.ContainerRegistry/registries/radix${module.config.environment}app"
    }
    vulnerability_scan_contributor = {
      role     = "Managed Identity Contributor"
      scope_id = "/subscriptions/${module.config.subscription}/resourceGroups/vulnerability-scan-${module.config.environment}"
    }
    cost_allocation_contributor = {
      role     = "Managed Identity Contributor"
      scope_id = "/subscriptions/${module.config.subscription}/resourceGroups/cost-allocation-${module.config.environment}"
    }
    grafana_contributor = {
      role     = "Managed Identity Contributor"
      scope_id = "/subscriptions/${module.config.subscription}/resourceGroups/monitoring"
    }
  }
  federated_credentials = {
    radix-id-gitrunner = {
      name    = "radix-id-gitrunner-${module.config.environment}"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix:environment:${module.config.environment}"
    },
    github_radix-platform = {
      name    = "radix-platform-env-${module.config.environment}"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-platform:environment:${module.config.environment}"
    }
  }
}

module "rediscache" {
  source              = "../../../modules/redis_cache"
  name                = "radix-${module.config.environment}"
  rg_name             = module.config.cluster_resource_group
  vnet_resource_group = module.config.vnet_resource_group
  sku_name            = "Standard"
  location            = module.config.location
}

output "workspace_id" {
  value = module.loganalytics.workspace_id
}

output "log_storageaccount_id" {
  value = module.storageaccount["log"].data.id
}

output "acr_id" {
  value = module.acr.azurerm_container_registry_id
}
