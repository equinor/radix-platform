variable "ampls_name" {
  description = "Name of the AMPLS instance."
  type        = string
}

variable "resource_group_name" {
  description = "Resource group containing the AMPLS instance."
  type        = string
}

variable "private_endpoint_resource_group_name" {
  description = "Resource group containing the AMPLS private endpoint."
  type        = string
}

variable "private_endpoint_name" {
  description = "Name of the private endpoint for AMPLS."
  type        = string
  default     = null

  validation {
    condition     = try(trimspace(var.private_endpoint_name) != "", false)
    error_message = "private_endpoint_name must be provided."
  }
}

variable "location" {
  description = "Azure location for the AMPLS private endpoint."
  type        = string
  default     = null

  validation {
    condition     = try(trimspace(var.location) != "", false)
    error_message = "location must be provided."
  }
}

variable "subnet_id" {
  description = "Subnet ID where the AMPLS private endpoint is created."
  type        = string
  default     = null

  validation {
    condition     = try(trimspace(var.subnet_id) != "", false)
    error_message = "subnet_id must be provided."
  }
}

variable "private_dns_zones" {
  description = "Map of private DNS zones available to the AMPLS private endpoint."
  type        = map(any)
  default     = {}

  validation {
    condition = alltrue([
      for zone in [
        "privatelink.monitor.azure.com",
        "privatelink.oms.opinsights.azure.com",
        "privatelink.ods.opinsights.azure.com",
        "privatelink.agentsvc.azure-automation.net",
        "privatelink.blob.core.windows.net",
      ] : contains(keys(var.private_dns_zones), zone) && try(trimspace(var.private_dns_zones[zone].id) != "", false)
    ])
    error_message = "The Azure Monitor private DNS zones must be provided with IDs."
  }
}