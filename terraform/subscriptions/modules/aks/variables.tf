variable "subscription" {
  type = string
}

variable "cluster_name" {
  type = string
}

variable "resource_group" {
  type = string
}

variable "location" {
  type = string
}

variable "dns_prefix" {
  type = string
}

variable "aks_version" {
  type = string
}

variable "cost_analysis" {
  type    = bool
  default = false
}

variable "authorized_ip_ranges" {
  type = list(string)
}

variable "developers" {
  type = list(string)
  # default = []
}

variable "tenant_id" {
  type    = string
  default = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
}

variable "systempool" {
  type = object({
    vm_size   = string
    tags      = optional(map(string))
    min_nodes = number
    max_nodes = number
    os_sku    = optional(string, "Ubuntu")
  })
}

variable "identity_aks" {
  type = string
}

variable "identity_kublet_client" {
  type = string
}
variable "identity_kublet_object" {
  type = string
}
variable "identity_kublet_identity_id" {
  type = string
}

variable "defender_workspace_id" {
  type = string
}

variable "network_policy" {
  description = "Specifies the data plane used for building the Kubernetes network. Currently supported values are calico, azure and cilium"
  type        = string
  default     = "calico"
}

variable "network_data_plane" {
  description = "The AKS network data plane to use."
  type        = string
}

variable "network_plugin_mode" {
  description = "The AKS network plugin mode to use."
  type        = string
  default     = null
}

variable "outbound_ip_address_ids" {
  type = list(any)
}

variable "nodepools" {
  type = map(object({
    vm_size         = string
    min_count       = number
    max_count       = number
    node_count      = optional(number, 1)
    node_labels     = optional(map(string))
    node_taints     = optional(list(string), [])
    os_disk_type    = optional(string, "Managed")
    nodepool_os_sku = optional(string, "Ubuntu")

  }))
}

variable "storageaccount_id" {
  description = "The ID of the Storage Account"
  type        = string
}

variable "address_space" {
  description = "Address space"
  type        = string
}

variable "enviroment" {
  description = "Enviroment"
  type        = string
}

variable "containers_workspace_id" {
  type = string
}

variable "vnethub_id" {
  type = string
}

variable "dnszones" {
  type    = list(string)
  default = []
}

variable "cluster_vnet_resourcegroup" {
  type = string
}

variable "active_cluster" {
  type    = bool
  default = false
}

variable "hostencryption" {
  type    = bool
  default = false
}

variable "cluster_lock" {
  type    = bool
  default = true
}

variable "enable_workload_identity" {
  description = "Enable workload identity on the AKS cluster."
  type        = bool
  default     = false
}

variable "sku_tier" {
  type    = string
  default = "Standard"
}

variable "node_os_upgrade_channel" {
  type    = string
  default = "None"
}

variable "nsg_name" {
  description = "Network Security Group name."
  type        = string
}

variable "vnet_name" {
  description = "Virtual Network name."
  type        = string
}

variable "subnet_name" {
  description = "Subnet name."
  type        = string
}

variable "enable_ddos_protection_plan" {
  description = "Enable DDoS protection plan on VNet."
  type        = bool
  default     = false
}

variable "ddos_protection_plan_id" {
  description = "Resource ID of the DDoS protection plan."
  type        = string
  default     = "/subscriptions/ded7ca41-37c8-4085-862f-b11d21ab341a/resourceGroups/rg-protection-we/providers/Microsoft.Network/ddosProtectionPlans/ddos-protection"
}

variable "enable_network_lock" {
  description = "Enable management lock on the VNet."
  type        = bool
  default     = false
}

variable "network_lock_name" {
  description = "Management lock name for the VNet lock."
  type        = string
}

variable "hub_virtual_network_name" {
  description = "Hub virtual network name used by hub_to_cluster peering."
  type        = string
}

variable "hub_to_cluster_peering_name" {
  description = "Peering name for hub to cluster direction."
  type        = string
}

variable "cluster_to_hub_peering_name" {
  description = "Peering name for cluster to hub direction."
  type        = string
}

variable "cluster_to_hub_resource_group" {
  description = "Resource group of the cluster VNet for the cluster_to_hub peering."
  type        = string
}

variable "private_dns_zone_link_name" {
  description = "Private DNS zone virtual network link name."
  type        = string
}

variable "monitor_data_collection_rule_name" {
  description = "Data collection rule name."
  type        = string
}

variable "monitor_interval" {
  description = "Container insights collection interval."
  type        = string
  default     = "1m"

  validation {
    condition     = contains(["1m", "5m"], var.monitor_interval)
    error_message = "monitor_interval must be one of: 1m, 5m."
  }
}

variable "tags" {
  description = "Tags to apply to the AKS cluster."
  type        = map(string)
  default     = {}
}