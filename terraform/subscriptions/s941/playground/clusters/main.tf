module "resourcegroups" {
  for_each = toset(var.resource_groups)
  source   = "../../../modules/resourcegroups"
  name     = each.value
  location = local.outputs.location
}

module "radix_id_external_secrets_operator_mi" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-external-secrets-operator-${local.external_outputs.common.data.enviroment}"
  location            = local.outputs.location
  resource_group_name = "common-${local.external_outputs.common.data.enviroment}"

}

module "policyassignment_resourcegroup" {
  for_each             = module.resourcegroups
  source               = "../../../modules/policyassignment_resourcegroup"
  policy_name          = "Radix-Enforce-Diagnostics-AKS-Clusters"
  location             = each.value["data"].location
  resource_group_id    = each.value["data"].id
  policy_definition_id = local.external_outputs.global.policy_aks_cluster_id
  identity_ids         = local.external_outputs.common.mi_id
  workspaceId          = local.external_outputs.common.workspace_id

}


module "nsg" {
  source                     = "../../../modules/networksecuritygroup"
  for_each                   = local.flattened_clusters
  networksecuritygroupname   = "nsg-${each.key}"
  location                   = each.value.location
  resource_group_name        = each.value.resource_group_name
  destination_address_prefix = each.value.destination_address_prefix
}
