variable "AZ_RESOURCE_GROUP_COMMON" {
  description = "Resource group name for common"
  type        = string
}

variable "AZ_LOCATION" {
  description = "Azure resource location"
  type        = string
}

variable "AZ_SUBSCRIPTION_ID" {
  type = string
}

variable "private_link" {
  description = "Subnet connection."
  type        = map(object({
    linkname = string
  }))
  default = null
}
variable "virtual_networks" {
  type = map(object({
    rg_name = string
  }))
  default = {
    "dev" = {
      rg_name = "cluster-vnet-hub-dev"
    }
    "playground" = {
      rg_name = "cluster-vnet-hub-playground"
    }
  }
}

variable "aks_clouster_resource_groups" {
  type = list(string)
}
variable "resource_groups" {
  type = map(object({
    name     = string                          # Mandatory
    location = optional(string, "northeurope") # Optional
  }))
  default = {}
}

variable "AZ_RESOURCE_GROUP_CLUSTERS" {
  type = string
}

variable "K8S_ENVIROMENTS" {
  description = "A map of cluster enviroments and their resource group"
  type        = map(object({
    name          = string
    resourceGroup = string
  }))
}

variable "key_vault_by_k8s_environment" {
  description = "Name of Keyvault."
  type        = map(object({
    name    = string
    rg_name = string
  }))
  default = {}
}

variable "ACR_TOKEN_EXPIRES_AT" {
  type = string
}

variable "EQUINOR_WIFI_IP_CIDR" {
  description = "Range of IP addresses to allow firewall connections."
  type        = string
}
