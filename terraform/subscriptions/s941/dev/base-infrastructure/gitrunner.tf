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
      scope_id = "${module.resourcegroups_common.data.id}"
    }
    common_legacy = {
      role     = "Contributor"
      scope_id = "${data.azurerm_resource_group.common.id}"
    }
    logs_contributor = {
      role     = "Contributor"
      scope_id = "${data.azurerm_resource_group.logs.id}"
    }
    clusters_contributor = {
      role     = "Contributor"
      scope_id = module.resourcegroups.data.id
    }
    networkwatcher_contributor = {
      role     = "Contributor"
      scope_id = "${data.azurerm_resource_group.networkwatcher.id}"
    }
    keyvault_contributor = {
      role     = "Key Vault Secrets User" # Needed to read secrets
      scope_id = "${module.keyvault.vault_id}"
    }
    vnet_contributor = {
      role = "Contributor"
      # scope_id = "/subscriptions/${module.config.subscription}/resourceGroups/${data.azurerm_virtual_network.this.resource_group_name}"
      scope_id = module.vnet_resourcegroup.data.id
    }
    app_registry_contributor = {
      role     = "Contributor"
      scope_id = module.acr.azurerm_container_registry_app_id
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