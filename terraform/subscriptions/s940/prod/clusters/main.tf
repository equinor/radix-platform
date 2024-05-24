

module "config" {
  source = "../../../modules/config"
}

module "resourcegroups" {
  for_each = toset(var.resource_groups)
  source   = "../../../modules/resourcegroups"
  name     = each.value
  location = module.config.location
}

data "azurerm_key_vault" "keyvault" {
  name                = module.config.key_vault_name
  resource_group_name = module.config.common_resource_group
}

data "azurerm_log_analytics_workspace" "workspace" {
  name                = module.config.log_analytics_name
  resource_group_name = module.config.common_resource_group
}

data "azurerm_storage_account" "velero" {
  name                = "radixvelero${module.config.environment}"
  resource_group_name = module.config.common_resource_group
}

# data "azurerm_container_registry" "this" {
#   name                = "radixprodapp" #TODO
#   resource_group_name = "common"       #TODO
# }

data "azurerm_policy_definition" "policy_aks_cluster" {
  display_name = module.config.policy_aks_diagnostics_cluster
}

module "radix_id_external_secrets_operator_mi" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-external-secrets-operator-${module.config.environment}"
  location            = module.config.location
  resource_group_name = "common-${module.config.environment}"
  roleassignments = {
    kv_user = {
      role     = "Key Vault Secrets Officer"
      scope_id = data.azurerm_key_vault.keyvault.id
    }
  }
}

# module "radix_id_acr_mi" {
#   source              = "../../../modules/userassignedidentity"
#   name                = "radix-id-acr-${module.config.environment}"
#   location            = module.config.location
#   resource_group_name = "common-${module.config.environment}"
#   roleassignments = {
#     pull = {
#       role     = "AcrPull"
#       scope_id = data.azurerm_container_registry.this.id
#     }
#     push = {
#       role     = "AcrPush"
#       scope_id = data.azurerm_container_registry.this.id
#     }
#   }
# }

module "radix_id_velero_mi" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-velero-${module.config.environment}"
  location            = module.config.location
  resource_group_name = "common-${module.config.environment}"
  roleassignments = {
    sac_user = {
      role     = "Storage Blob Data Contributor"
      scope_id = data.azurerm_storage_account.velero.id
    }
  }
}

module "nsg" {
  source                     = "../../../modules/networksecuritygroup"
  for_each                   = local.flattened_clusters
  networksecuritygroupname   = "nsg-${each.key}"
  location                   = each.value.location
  resource_group_name        = each.value.resource_group_name
  destination_address_prefix = each.value.destination_address_prefix
}
