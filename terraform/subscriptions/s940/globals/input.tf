locals {
  flattened_resource_groups = {
    for key, value in var.resource_groups : key => {
      name     = key
      location = value.location
    }
  }
}