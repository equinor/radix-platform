data "azurerm_user_assigned_identity" "this" {
  resource_group_name = module.config.common_resource_group
  name                = "radix-id-external-secrets-operator-${module.config.environment}"
}

locals {
  namespaces = ["default", "flux-system", "radix-cicd-canary"]
  eso_namespaced_credentials = merge([
    for cluster_key, issuer_url in module.clusters.oidc_issuer_url : {
      for namespace in local.namespaces :
      "${cluster_key}-${namespace}" => {
        cluster_key = cluster_key
        issuer_url  = issuer_url
        namespace   = namespace
      }
    }
  ]...)
}

module "eso" {
  source              = "../../../modules/federated-credentials"
  for_each            = module.clusters.oidc_issuer_url
  name                = "operator-wi-${each.key}"
  issuer              = each.value
  subject             = "system:serviceaccount:external-secrets:workload-identity-sa"
  parent_id           = data.azurerm_user_assigned_identity.this.id
  resource_group_name = data.azurerm_user_assigned_identity.this.resource_group_name
  depends_on          = [module.aks]
}

module "eso_namespaced" {
  source              = "../../../modules/federated-credentials"
  for_each            = local.eso_namespaced_credentials
  name                = "operator-wi-${each.value.cluster_key}-${each.value.namespace}"
  issuer              = each.value.issuer_url
  subject             = "system:serviceaccount:${each.value.namespace}:workload-identity-sa"
  parent_id           = data.azurerm_user_assigned_identity.this.id
  resource_group_name = data.azurerm_user_assigned_identity.this.resource_group_name
  depends_on          = [module.aks]
}