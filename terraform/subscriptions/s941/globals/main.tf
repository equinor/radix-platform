module "resourcegroups" {
  for_each = local.flattened_resource_groups
  source   = "../../modules/resourcegroups"
  name     = each.value.name
  location = each.value.location
}
