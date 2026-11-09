module "keyvault_lock_creator_role" {
  source = "../roles"

  name        = "Radix Key Vault Lock Creator ${coalesce(var.locker_environment, var.environment)}"
  scope       = var.subscription_id
  description = var.enable_resource_locks ? "Can read the main Key Vault and create or read locks, but cannot delete locks." : "Can read and update the main Key Vault configuration."
  actions = concat(
    ["Microsoft.KeyVault/vaults/read", "Microsoft.KeyVault/vaults/write"],
    var.enable_resource_locks ? ["Microsoft.Authorization/locks/read", "Microsoft.Authorization/locks/write"] : []
  )
  assignable_scopes = [var.subscription_id]
}

module "radix_id_gitrunner_locker" {
  source = "../userassignedidentity"

  name                = "radix-id-gitrunner-locker-${coalesce(var.locker_environment, var.environment)}"
  location            = var.location
  resource_group_name = var.common_resource_group_name
  roleassignments = merge({
    storage_blob_data_reader = {
      role     = "Storage Blob Data Reader"
      scope_id = var.terraform_state_storage_account_id
    }
    keyvault_lock_creator = {
      role     = module.keyvault_lock_creator_role.name
      scope_id = var.key_vault_id
    }
    }, var.enable_resource_locks ? {
    lock_operator = {
      role     = "Locks Contributor"
      scope_id = var.clusters_resource_group_id
    }
    cluster_resource_reader = {
      role     = "Reader"
      scope_id = var.clusters_resource_group_id
    }
  } : {})
  federated_credentials = {
    github_radix-platform = {
      name    = "radix-platform-env-${var.environment}"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-platform:ref:refs/heads/master"
    }
  }
  depends_on = [module.base.keyvault_lock_creator_role]
}