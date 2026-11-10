module "common_resource_group" {
  for_each = toset(var.managed_resource_group_names)
  source   = "../resourcegroups"

  name     = each.value
  location = var.location
}
