

module "config" {
  source = "../../../modules/config"
}

module "resourcegroups" {
  for_each = toset(var.resource_groups)
  source   = "../../../modules/resourcegroups"
  name     = each.value
  location = module.config.location
}

data "azurerm_resource_group" "clusters" {
  name = "clusters-${module.config.environment}"
}

data "azurerm_resource_group" "common" {
  name = "monitoring" #TODO
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

data "azurerm_container_registry" "this" {
  name                = "radixprod"
  resource_group_name = "common" #TODO
}

data "azurerm_container_registry" "cache" {
  name                = "radixplatformcache"
  resource_group_name = "common-platform" #TODO
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

module "radix_id_canary_scaler_mi" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-canary-scaler-${module.config.environment}"
  location            = module.config.location
  resource_group_name = "common-${module.config.environment}"
  roleassignments = {
    command_runner = {
      role     = "Radix Azure Kubernetes Service Command Runner"
      scope_id = data.azurerm_resource_group.clusters.id
    }
  }
}

module "radix_id_akskubelet_mi" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-akskubelet-${module.config.environment}"
  location            = module.config.location
  resource_group_name = "common-${module.config.environment}"
  roleassignments = {
    arcpull = {
      role     = "AcrPull"
      scope_id = data.azurerm_container_registry.this.id
    }
    arccache = {
      role     = "AcrPull"
      scope_id = data.azurerm_container_registry.cache.id
    }
  }
}

module "radix_id_aks_mi" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-aks-${module.config.environment}"
  location            = module.config.location
  resource_group_name = "common-${module.config.environment}"
  roleassignments = {
    mi_operator = {
      role     = "Managed Identity Operator"
      scope_id = module.radix_id_akskubelet_mi.data.id
    }
    rg_contributor = {
      role     = "Contributor"
      scope_id = data.azurerm_resource_group.common.id
    }
  }
}

#Legacy AKSkubelet MI
module "id_radix_akskubelet_mi" {
  source              = "../../../modules/userassignedidentity"
  name                = "id-radix-akskubelet-${module.config.environment}-${module.config.location}"
  location            = module.config.location
  resource_group_name = module.config.common_resource_group
  roleassignments = {
    arcpull = {
      role     = "AcrPull"
      scope_id = data.azurerm_container_registry.this.id
    }
  }
}

#Legacy AKS MI
module "id_radix_aks_mi" {
  source              = "../../../modules/userassignedidentity"
  name                = "id-radix-aks-${module.config.environment}-${module.config.location}"
  location            = module.config.location
  resource_group_name = module.config.common_resource_group
  roleassignments = {
    mi_operator = {
      role     = "Managed Identity Operator"
      scope_id = module.id_radix_akskubelet_mi.data.id
    }
    rg_contributor = {
      role     = "Contributor"
      scope_id = data.azurerm_resource_group.common.id
    }
  }
}

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

output "radix_id_aks_mi_id" {
  value = module.radix_id_aks_mi.data.id
}

output "radix_id_akskubelet_mi_id" {
  value = module.radix_id_akskubelet_mi.data.id
}