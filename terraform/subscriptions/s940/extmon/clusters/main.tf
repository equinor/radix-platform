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