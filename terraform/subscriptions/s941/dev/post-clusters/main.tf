
module "config" {
  source = "../../../modules/config"
}


data "azurerm_kubernetes_cluster" "this" {
  for_each = toset(module.config.cluster_names)

  resource_group_name = "clusters-development" # module.config.cluster_resource_group TODO: FIXME PLEASE!
  name = each.value
}


data "azurerm_user_assigned_identity" "this" {
  resource_group_name = module.config.common_resource_group
  name ="radix-id-external-secrets-operator-${module.config.environment}"
}
resource "azurerm_federated_identity_credential" "eso" {
  for_each = toset(module.config.cluster_names)

  audience            = ["api://AzureADTokenExchange"]
  issuer              = data.azurerm_kubernetes_cluster.this[each.key].oidc_issuer_url
  name                = "operator-wi-${each.key}"
  parent_id           = data.azurerm_user_assigned_identity.this.id
  resource_group_name = module.config.common_resource_group
  subject             = "system:serviceaccount:external-secrets:workload-identity-sa"
}
