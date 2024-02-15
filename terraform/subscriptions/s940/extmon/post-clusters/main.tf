
module "config" {
  source = "../../../modules/config"
}

resource "local_file" "templates" {
  for_each = toset([
    for file in fileset(path.module, "templates/**") :      # The subfolder in current dir
    file if length(regexall(".*app-template.*", file)) == 0 # Ignore paths with "app-template"
  ])

  content = templatefile(each.key, {
    identity_id = data.azurerm_user_assigned_identity.this.client_id
  })

  filename = replace("${path.module}/${each.key}", "templates", "rendered")
}


data "azurerm_kubernetes_cluster" "this" {
  for_each = toset(module.config.cluster_names)

  resource_group_name = "monitoring" # module.config.cluster_resource_group # wip
  name                = each.value
}


data "azurerm_user_assigned_identity" "this" {
  resource_group_name = module.config.common_resource_group
  name                = "radix-id-external-secrets-operator-${module.config.environment}"
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
