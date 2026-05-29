variable "application_id" {
  type        = string
  description = "The Azure AD application ID for the Radix Web Console app registration"
}

variable "dns_zone_name" {
  type        = string
  description = "The DNS zone name (e.g. radix.equinor.com)"
}

variable "cluster_names" {
  type        = map(any)
  description = "Map keyed by cluster name, as returned by the active-clusters module's oidc_issuer_url output"
}
