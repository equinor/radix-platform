variable "application_id" {
  type        = string
  description = "The Azure AD application ID for the Grafana app registration"
}

variable "dns_zone_name" {
  type        = string
  description = "The DNS zone name (e.g. radix.equinor.com)"
}

variable "cluster_names" {
  type        = map(any)
  description = "Map keyed by cluster name, as returned by the active-clusters module's oidc_issuer_url output"
}

variable "grafana_root_hostname" {
  type        = string
  default     = "grafana"
  description = "Hostname for the root Grafana URI. Defaults to 'grafana'; use 'grafana.ext-mon' for the extmon environment"
}
