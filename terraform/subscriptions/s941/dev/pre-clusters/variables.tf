variable "aksclusters" {
  description = "Max 15 characters lowercase in the storageaccount name"
  type = map(object({
    autostartupschedule     = optional(bool, "false")
    migrationStrategy       = optional(string, "aa")
    outbound_ip_address_ids = list(string)
    node_os_upgrade_channel = optional(string, "None")
  }))
  default = {
    weekly-43 = {
      outbound_ip_address_ids = ["/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/common/providers/Microsoft.Network/publicIPAddresses/pip-radix-aks-development-northeurope-001", "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/common/providers/Microsoft.Network/publicIPAddresses/pip-radix-aks-development-northeurope-002"]


    },
    weekly-44 = {
      autostartupschedule     = true
      outbound_ip_address_ids = ["/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/common/providers/Microsoft.Network/publicIPAddresses/pip-radix-aks-development-northeurope-003", "/subscriptions/16ede44b-1f74-40a5-b428-46cca9a5741b/resourceGroups/common/providers/Microsoft.Network/publicIPAddresses/pip-radix-aks-development-northeurope-004"]
    }
  }
}