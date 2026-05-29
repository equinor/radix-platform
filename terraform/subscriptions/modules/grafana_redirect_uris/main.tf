locals {
  per_cluster_uris = flatten([
    for k, v in var.cluster_names : [
      "https://grafana.${k}.${var.dns_zone_name}/login/generic_oauth",
      "https://grafana.${k}.${var.dns_zone_name}/login/azuread",
    ]
  ])
}

module "grafana_redirect_uris" {
  source         = "../app_registration_redirect_uris"
  application_id = var.application_id
  type           = "Web"
  redirect_uris = concat(
    [
      "https://${var.grafana_root_hostname}.${var.dns_zone_name}/login/generic_oauth",
      "https://${var.grafana_root_hostname}.${var.dns_zone_name}/login/azuread",
    ],
    local.per_cluster_uris,
  )
}
