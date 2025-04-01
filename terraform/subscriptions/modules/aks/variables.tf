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
  type    = string
  default = ""
}

variable "aks_version" {
  type = string
}

variable "cost_analysis" {
  type    = bool
  default = false
}

variable "workload_identity_enabled" {
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

variable "outbound_ip_address_ids" {
  type = list(any)
}

variable "nodepools" {
  type = map(object({
    vm_size      = string
    min_count    = number
    max_count    = number
    node_count   = optional(number, 1)
    node_labels  = optional(map(string))
    node_taints  = optional(list(string), [])
    os_disk_type = optional(string, "Managed")
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

variable "service_endpoints" {
  type    = list(string)
  default = []
}

variable "ingressIP" {
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

variable "common_resource_group" {
  type = string
}

variable "active_cluster" {
  type    = bool
  default = false
}

