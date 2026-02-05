

data "azurerm_user_assigned_identity" "externaldns" {
  name                = "radix-id-external-dns-${module.config.environment}"
  resource_group_name = module.config.common_resource_group
}

resource "azurerm_federated_identity_credential" "externaldns" {
  for_each       = module.clusters.oidc_issuer_url
  name                = each.key
  resource_group_name = module.config.common_resource_group
  audience            = ["api://AzureADTokenExchange"]
  issuer         = each.value
  parent_id           = data.azurerm_user_assigned_identity.externaldns.id
  subject        = "system:serviceaccount:external-dns:external-dns"
}