module "radix_id_privatelinks" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-gitrunner-privatelinks-${module.config.new_environment}"
  resource_group_name = module.config.common_resource_group
  location            = module.config.location
  roleassignments = {
    # Storage and Blob Access
    storage_blob_data_contributor = {
      role     = "Storage Blob Data Contributor" # Needed to manage blobs and containers (read/write/delete data)
      scope_id = data.azurerm_storage_account.terraform_state.id
    }
    # Infrastructure: Networking
    cluster_vnet_hub = {
      role     = "Private DNS Zone Contributor"
      scope_id = module.resourcegroup_vnet.data.id
    }
    # Custom Roles
    privatelink-network = {
      role     = "Radix Privatelink rbac-${module.config.subscription_shortname}"
      scope_id = module.resourcegroup_vnet.data.id
    }
  }
  federated_credentials = {
    radix-internal_federated = {
      name    = "radix-id-gitrunner-privatelinks-${module.config.new_environment}"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-internal:ref:refs/heads/main"
    }
  }
}