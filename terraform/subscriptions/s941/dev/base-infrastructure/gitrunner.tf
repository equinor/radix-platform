module "keyvault_lock_creator_role" {
  source            = "../../../modules/roles"
  name              = "Radix Key Vault Lock Creator ${module.config.environment}"
  scope             = data.azurerm_subscription.current.id
  description       = "Can read and update the main Key Vault configuration."
  actions           = ["Microsoft.KeyVault/vaults/read", "Microsoft.KeyVault/vaults/write"]
  assignable_scopes = [data.azurerm_subscription.current.id]
}

module "radix_id_gitrunner_locker" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-gitrunner-locker-${module.config.environment}"
  location            = module.config.location
  resource_group_name = module.config.common_resource_group
  roleassignments = {
    storage_blob_data_reader = {
      role     = "Storage Blob Data Reader"
      scope_id = data.azurerm_storage_account.terraform_state.id
    }
    keyvault_lock_creator = {
      role     = module.keyvault_lock_creator_role.name
      scope_id = module.keyvault.azurerm_key_vault_id
    }
  }
  federated_credentials = {
    github_radix-platform = {
      name    = "radix-platform-env-${module.config.environment}"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-platform:ref:refs/heads/master"
    }
  }
  depends_on = [module.keyvault_lock_creator_role]
}

module "radix_id_gitrunner" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-gitrunner-${module.config.environment}"
  resource_group_name = module.config.common_resource_group
  location            = module.config.location
  roleassignments = {
    # Storage and Blob Access
    storage_blob_data_contributor = {
      role     = "Storage Blob Data Contributor" # Needed to manage blobs and containers (read/write/delete data)
      scope_id = data.azurerm_storage_account.terraform_state.id
    }
    # Container Registry
    container_registry_app = {
      role     = "Contributor"
      scope_id = module.acr.azurerm_container_registry_app_id
    }
    container_registry_app_abac_contributor = {
      role     = "Container Registry Repository Contributor"
      scope_id = module.acr.azurerm_container_registry_app_id
    }
    container_registry_app_abac_lister = {
      role     = "Container Registry Repository Catalog Lister"
      scope_id = module.acr.azurerm_container_registry_app_id
    }
  }
  federated_credentials = {
    radix-id-gitrunner = {
      name    = "radix-id-gitrunner-${module.config.environment}"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-internal:ref:refs/heads/main"
    },
    github_radix-platform = {
      name    = "radix-platform-env-${module.config.environment}"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-platform:ref:refs/heads/master"
    },
    radix-id-gitrunner-radix_pull = {
      name    = "radix-id-gitrunner-${module.config.environment}-radix_pull"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-internal:pull_request"
    }
  }
}

output "radix_id_gitrunner_locker_client_id" {
  value = module.radix_id_gitrunner_locker.client-id
}