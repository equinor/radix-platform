locals {
  gh_repos = {
    "radix-canary" : ["release", "master"]
  }
  
  flattened_resource_groups = {
    for key, value in var.resource_groups : key => {
      name     = key
      location = value.location
    }
  }
}
