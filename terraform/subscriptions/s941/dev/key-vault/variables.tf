variable "keyvaults" {
  description = "Key Vaults"
  type = map(object({
    resource_group              = optional(string, "common-dev")
    soft_delete_retention_days  = optional(number, 30)
    enable_rbac_authorization   = optional(bool, false)
    purge_protection_enabled    = optional(bool, true)
    network_acls_default_action = optional(string, "Allow")
    kv_secrets_user_id          = optional(string, "")
  }))
  default = {
    radix-keyv-dev = {
      resource_group            = "common-dev"
      enable_rbac_authorization = true
      kv_secrets_user_id        = "e1cab00e-9c12-4ce1-9882-842a57e89643"

    }
  }

}