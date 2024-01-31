
module "resourcegroups" {
  for_each = toset(var.resource_groups)
  source   = "../../../modules/resourcegroups"
  name     = each.value
  location = local.outputs.location
}


module "clusters" {
  source   = "../../../modules/clusters"
  resource_groups = var.resource_groups
  subscription = "16ede44b-1f74-40a5-b428-46cca9a5741b"
}

data "azurerm_kubernetes_cluster" "k8s" {
  for_each = module.clusters.k8s_resources

  name = each.value.name
  resource_group_name = each.value.resource_group
}

resource "azurerm_subscription_policy_assignment" "cluster-vlan" {
  for_each = data.azurerm_kubernetes_cluster.k8s

  name                 = "some-assignement"
  policy_definition_id = ""
  subscription_id      = ""

  parameters = {
    vlanId = each.value.ag
  }
}
