variable "keyvaults" {
  description = "Key Vaults"
  type = map(object({
    resource_group              = optional(string, "common-c2")
    soft_delete_retention_days  = optional(number, 30)
    enable_rbac_authorization   = optional(bool, false)
    purge_protection_enabled    = optional(bool, true)
    network_acls_default_action = optional(string, "Allow")
  }))
  default = {
    radix-keyv-c2 = {
      enable_rbac_authorization = true
    }
  }

}