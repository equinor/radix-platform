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
    rg_contributor = {
      role     = "Contributor"
      scope_id = data.azurerm_resource_group.common.id
    }
    rg_common_zone = {
      role     = "Contributor"
      scope_id = module.resourcegroup_common.data.id
    }
  }
}


#Legacy AKSkubelet MI - Check to verify for removal
#az aks show -g {resource group} -n {clustername} | jq -r .identityProfile.kubeletidentity.resourceId

module "id_radix_akskubelet_mi" {
  source              = "../../../modules/userassignedidentity"
  name                = "id-radix-akskubelet-${module.config.environment}-prod" #TODO
  location            = module.config.location
  resource_group_name = "common-westeurope" #TODO
  roleassignments = {
    arcpull = {
      role     = "AcrPull"
      scope_id = module.acr.azurerm_container_registry_id
    }
  }
}

#Legacy AKS MI
module "id_radix_aks_mi" {
  source              = "../../../modules/userassignedidentity"
  name                = "id-radix-aks-${module.config.environment}-prod"
  location            = module.config.location
  resource_group_name = "common-westeurope" #TODO
  roleassignments = {
    mi_akskubelet = {
      role     = "Managed Identity Operator"
      scope_id = module.id_radix_akskubelet_mi.data.id
    }
  }
}