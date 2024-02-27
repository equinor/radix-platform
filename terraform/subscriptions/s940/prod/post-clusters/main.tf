module "config" {
  source = "../../../modules/config"
}

data "azapi_resource_list" "clusters" {
  type      = "Microsoft.ContainerService/managedClusters@2023-09-01"
  parent_id = "/subscriptions/${module.config.backend.subscription_id}/resourcegroups/clusters" #TODO with code below after cluster in new RG
  #parent_id              = "/subscriptions/${module.config.backend.subscription_id}/resourcegroups/${module.config.cluster_resource_group}"
  response_export_values = ["*"]
}

locals {
  clusters = { for k, v in jsondecode(data.azapi_resource_list.clusters.output).value : v.name => v.id }
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
  for_each            = local.clusters
  resource_group_name = "clusters" #TODO with code below after cluster in new RG
  #resource_group_name = module.config.cluster_resource_group
  name = each.key
}

data "azurerm_user_assigned_identity" "this" {
  resource_group_name = module.config.common_resource_group
  name                = "radix-id-external-secrets-operator-${module.config.environment}"
}

resource "azurerm_federated_identity_credential" "eso" {
  for_each = local.clusters

  audience            = ["api://AzureADTokenExchange"]
  issuer              = data.azurerm_kubernetes_cluster.this[each.key].oidc_issuer_url
  name                = "operator-wi-${each.key}"
  parent_id           = data.azurerm_user_assigned_identity.this.id
  resource_group_name = module.config.common_resource_group
  subject             = "system:serviceaccount:external-secrets:workload-identity-sa"
}
