module "base" {
  source                     = "../../../modules/base-infrastructure"
  clusters_resource_group_id = module.resourcegroup_clusters.data.id
  ampls = {
    ampls_enabled               = module.config.ampls_enabled
    ampls_name                  = "radix-ampls-${module.config.new_environment}"
    ampls_resource_group        = "common-${module.config.new_environment}"
    ampls_private_endpoint_name = "pe-ampls-${module.config.new_environment}"
  }
  enable_resource_locks                          = true
  gitrunner_federated_credential_name            = "radix-platform-env-${module.config.new_environment}"
  gitrunner_locker_name                          = "radix-id-gitrunner-locker-${module.config.new_environment}"
  gitrunner_locker_resource_group_name           = module.config.common_resource_group
  network_security_perimeter_name                = "network-perimeter-${module.config.environment}"
  network_security_perimeter_resource_group_name = module.config.common_resource_group
  keyvault_lock_creator_role_name                = "Radix Key Vault Lock Creator ${module.config.new_environment}"
  keyvault_config_name                           = "radix-config-${module.config.environment}"
  keyvault_config_resource_group_name            = "common-${module.config.new_environment}"
  keyvault_name                                  = "radix-keyv-${module.config.environment}"
  keyvault_resource_group_name                   = module.config.common_resource_group
  keyvault_secrets_user_id                       = module.acr.azurerm_container_registry_credential_id
  keyvault_subscription_contributor              = module.config.subscription_contributor
  vnet_resource_group                            = module.config.vnet_resource_group
  common_resource_group                          = module.config.common_resource_group
  location                                       = module.config.location
  managed_resource_group_names                   = ["common-${module.config.new_environment}"] # Added managed resource group "common-c1" for the new environment
  subscription_id                                = data.azurerm_subscription.current.id
  terraform_state_storage_account_id             = data.azurerm_storage_account.terraform_state.id
  virtual_network_private_dns_zone               = module.azurerm_virtual_network.data.private_dns_zone
  virtual_network_subnet_id                      = module.azurerm_virtual_network.azurerm_subnet_id
}

#region External AMPLS workspaces
data "azurerm_key_vault_secret" "external_ampls_ids" {
  name         = "external-ampls-ids"
  key_vault_id = module.base.keyvault_config_id
}

locals {
  external_ampls_workspace_pattern = "(?i)^/subscriptions/(?P<subscription>[^/]+)/resourcegroups/(?P<resource_group>[^/]+)/providers/microsoft\\.operationalinsights/workspaces/(?P<name>[^/]+)$"

  # Only resource IDs are stored in this secret, not credentials.
  external_ampls_workspaces = [
    for id in split(",", nonsensitive(data.azurerm_key_vault_secret.external_ampls_ids.value)) :
    regex(local.external_ampls_workspace_pattern, trimspace(id))
  ]

  external_ampls_workspace_ids = {
    for workspace in local.external_ampls_workspaces :
    workspace.name => format(
      "/subscriptions/%s/resourceGroups/%s/providers/Microsoft.OperationalInsights/workspaces/%s",
      workspace.subscription,
      workspace.resource_group,
      workspace.name
    )
  }
}

resource "azurerm_monitor_private_link_scoped_service" "external_workspaces" {
  for_each = local.external_ampls_workspace_ids

  name                = each.key
  resource_group_name = "common-${module.config.new_environment}"
  scope_name          = module.base.ampls_name
  linked_resource_id  = each.value
}
#endregion External AMPLS workspaces

output "radix_id_gitrunner_locker_client_id" {
  value = module.base.radix_id_gitrunner_locker_client_id
}
