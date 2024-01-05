locals {
  flattened_config = {
    for key, value in var.roleassignment : key => {
      backup = value.backup
      kind   = var.kind
      
    }
  }
}
