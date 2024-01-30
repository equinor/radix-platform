
module "resourcegroups" {
  for_each = toset(var.resource_groups)
  source   = "../../../modules/resourcegroups"
  name     = each.value
  location = local.outputs.location
}


module "nsg" {
  source                     = "../../../modules/networksecuritygroup"
  for_each                   = local.flattened_clusters
  networksecuritygroupname   = "nsg-${each.key}"
  location                   = each.value.location
  resource_group_name        = each.value.resource_group_name
  destination_address_prefix = each.value.destination_address_prefix
}
