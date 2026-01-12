module "radix_id_gitrunner" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-gitrunner-${module.config.environment}"
  resource_group_name = module.config.common_resource_group
  location            = module.config.location
  roleassignments = {
    # Storage and Blob Access
    storage_account_contributor = {
      role     = "Storage Account Contributor" # Needed to manage Storage Account firewall and settings
      scope_id = data.azurerm_storage_account.terraform_state.id
    }
    storage_blob_data_contributor = {
      role     = "Storage Blob Data Contributor" # Needed to manage blobs and containers (read/write/delete data)
      scope_id = data.azurerm_storage_account.terraform_state.id
    }
    # Container Registry
    container_registry_app = {
      role     = "Contributor"
      scope_id = module.acr.azurerm_container_registry_app_id
    }
    #  Infrastructure: Networking
    k8s_command_runner = {
      role     = "Radix Azure Kubernetes Service Command Runner"
      scope_id = module.resourcegroup_clusters.data.id
    },
    cluster_vnet_hub = {
      role     = "Private DNS Zone Contributor"
      scope_id = module.resourcegroup_vnet.data.id
    }
    privatelink-contributor = {
      role     = "Radix Privatelink rbac-${module.config.subscription_shortname}"
      scope_id = "/subscriptions/${module.config.subscription}"
    }
    lock_operator = {
      role     = "Locks Contributor"
      scope_id = module.resourcegroup_clusters.data.id
    }
  }
  federated_credentials = {
    radix-id-gitrunner = {
      name    = "radix-id-gitrunner-${module.config.environment}"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix:ref:refs/heads/main"
    },
    github_radix-platform = {
      name    = "radix-platform-env-${module.config.environment}"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-platform:ref:refs/heads/master"
    },
    radix-id-gitrunner-radix_pull = {
      name    = "radix-id-gitrunner-${module.config.environment}-radix_pull"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix:pull_request"
    }
  }
}