variable "AZ_TENANT_ID" {
  description = "Tenant ID"
  type        = string
}

variable "AZ_SUBSCRIPTION_ID" {
  description = "Azure subscription id"
  type        = string
}

variable "AAD_RADIX_GROUP" {
  description = "Radix group name"
  type        = string
}

variable "RADIX_ZONE" {
  description = "Radix zone"
  type        = string
}

variable "github_workflow_repos" {
  description = "A map of GitHub repositories and their branches"
  type        = map(list(string))
}

variable "GH_ORGANIZATION" {
  description = "Github organization"
  type        = string
}
