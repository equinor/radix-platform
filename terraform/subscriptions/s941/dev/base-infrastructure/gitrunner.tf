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
      scope_id = data.azurerm_storage_account.terraform_state.id
    }
    storage_blob_contributor = {
      role     = "Storage Blob Data Contributor" # Needed to read blobdata
      scope_id = data.azurerm_storage_account.terraform_state.id
    }
    common_contributor = {
      role     = "Contributor" # Needed to open firewall
      scope_id = module.resourcegroup_common.data.id
    }
    common_legacy = {
      role     = "Contributor"
      scope_id = data.azurerm_resource_group.common.id
    }
    logs_contributor = {
      role     = "Contributor"
      scope_id = module.resourcegroup_logs.data.id
    }
    clusters_contributor = {
      role     = "Contributor"
      scope_id = module.resourcegroup_clusters.data.id
    }
    networkwatcher_contributor = {
      role     = "Contributor"
      scope_id = data.azurerm_resource_group.networkwatcher.id
    }
    app_configuration_reader = {
      role     = "App Configuration Data Reader"
      scope_id = module.keyvault.azurerm_app_configuration_id
    }
    vnet_contributor = {
      role     = "Contributor"
      scope_id = module.resourcegroup_vnet.data.id
    }
    app_registry_contributor = {
      role     = "Contributor"
      scope_id = module.acr.azurerm_container_registry_app_id
    }
    vulnerability_scan_contributor = {
      role     = "Managed Identity Contributor"
      scope_id = module.resourcegroup_vulnerability_scan.data.id
    }
    cost_allocation_contributor = {
      role     = "Managed Identity Contributor"
      scope_id = module.resourcegroup_cost_allocation.data.id
    }
    grafana_contributor = {
      role     = "Managed Identity Contributor"
      scope_id = data.azurerm_resource_group.monitoring.id
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