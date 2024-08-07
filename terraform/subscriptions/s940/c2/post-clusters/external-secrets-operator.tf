# resource "local_file" "templates" {
#   for_each = toset([
#     for file in fileset(path.module, "templates/**") :      # The subfolder in current dir
#     file if length(regexall(".*app-template.*", file)) == 0 # Ignore paths with "app-template"
#   ])
#
#   content = templatefile(each.key, {
#     identity_id = data.azurerm_user_assigned_identity.this.client_id
#   })
#
#   filename = replace("${path.module}/${each.key}", "templates", "rendered")
# }

data "azurerm_user_assigned_identity" "this" {
  resource_group_name = module.config.common_resource_group
  name                = "radix-id-external-secrets-operator-${module.config.environment}"
}

resource "azurerm_federated_identity_credential" "eso" {
  for_each = module.clusters.oidc_issuer_url

  audience            = ["api://AzureADTokenExchange"]
  issuer              = each.value
  name                = "operator-wi-${each.key}"
  parent_id           = data.azurerm_user_assigned_identity.this.id
  resource_group_name = module.config.common_resource_group
  subject             = "system:serviceaccount:external-secrets:workload-identity-sa"
}
