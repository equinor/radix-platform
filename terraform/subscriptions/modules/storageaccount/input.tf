locals {
  flattened_roleassignment = {
    for key, value in var.roleassignment : key => {
      backup           = value.backup
      kind             = var.kind
      private_endpoint = var.roleassignment
    }
  }
}

