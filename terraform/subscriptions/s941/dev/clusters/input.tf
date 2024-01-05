locals {
  flattened_clusters = {
    for key, value in var.clusters : key => {
      name                       = key
      resource_group_name        = value.resource_group_name
      location                   = value.location
      destination_address_prefix = value.destination_address_prefix
    }
  }
}

