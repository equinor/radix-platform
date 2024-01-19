module "resourcegroups" {
  for_each = toset(var.resource_groups)
  source   = "../../../modules/resourcegroups"
  name     = "${local.external_outputs.global.data.aad_radix_group}-${each.value}"
  location = local.outputs.location
}