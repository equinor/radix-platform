module "radix_id_gitrunner_locker" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-gitrunner-locker-${module.config.new_environment}"
  location            = module.config.location
  resource_group_name = module.resourcegroup_common.data.name
  roleassignments = {
    storage_blob_data_reader = {
      role     = "Storage Blob Data Reader"
      scope_id = data.azurerm_storage_account.terraform_state.id
    }
    k8s_command_runner = {
      role     = "Radix Azure Kubernetes Service Command Runner"
      scope_id = module.resourcegroup_clusters.data.id
    }
    lock_operator = {
      role     = "Locks Contributor"
      scope_id = module.resourcegroup_clusters.data.id
    }
  }
  federated_credentials = {
    github_radix-platform = {
      name    = "radix-platform-env-${module.config.new_environment}"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-platform:ref:refs/heads/master"
    }
  }
}

module "radix_id_akskubelet_mi" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-akskubelet-${module.config.environment}"
  location            = module.config.location
  resource_group_name = module.resourcegroup_common.data.name
  roleassignments = {
    arcpull = {
      role     = "AcrPull"
      scope_id = module.acr.azurerm_container_registry_id
    }
    arccache = {
      role     = "AcrPull"
      scope_id = module.acr.azurerm_container_registry_cache_id
    }
  }
}

module "radix_id_aks_mi" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-aks-${module.config.environment}"
  location            = module.config.location
  resource_group_name = module.resourcegroup_common.data.name
  roleassignments = {
    mi_operator = {
      role     = "Managed Identity Operator"
      scope_id = module.radix_id_akskubelet_mi.data.id
    }
    rg_cluster = {
      role     = "Contributor"
      scope_id = module.resourcegroup_clusters.data.id
    }
  }
}