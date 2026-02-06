locals {
  # Calculate the zone name based on environment
  zone_name = var.environment == "platform" || var.environment == "extmon" ? "radix.equinor.com" : "${var.environment}.radix.equinor.com"

  # Calculate resource group for extmon
  dns_resource_group = var.common_resource_group == "common-extmon" ? "common-platform" : var.common_resource_group

  # Select IP based on dns_wildcard_type
  cluster_ips = {
    for k, v in var.clusters :
    k => v.dns_wildcard_type == "istio" ? v.istio_ip : v.nginx_ip
  }

  # Active clusters for wildcard records
  active_clusters = {
    for k, v in var.clusters :
    k => v if v.active_cluster && var.environment != "extmon"
  }

  # Flatten active cluster records
  active_records = merge([
    for cluster_name, cluster in local.active_clusters : {
      for record in ["@", "*", "*.app"] :
      "${cluster_name}-${record}" => {
        name    = record
        ip      = local.cluster_ips[cluster_name]
        cluster = cluster_name
      }
    }
  ]...)
}

# Wait 10 seconds before creating DNS records (after destroy)
resource "time_sleep" "wait_after_destroy" {
  create_duration = "10s"

  triggers = {
    cluster_ips     = jsonencode(local.cluster_ips)
    active_records  = jsonencode(local.active_records)
    active_clusters = jsonencode(local.active_clusters)
  }
}

# Active cluster wildcard records
resource "azurerm_dns_a_record" "active" {
  for_each            = local.active_records
  name                = each.value.name
  zone_name           = local.zone_name
  resource_group_name = var.common_resource_group
  ttl                 = 30
  records             = [each.value.ip]

  depends_on = [time_sleep.wait_after_destroy]

  lifecycle {
    create_before_destroy = false
  }
}

# Cluster-specific wildcard records
resource "azurerm_dns_a_record" "cluster" {
  for_each            = var.clusters
  name                = "*.${each.value.cluster_name}"
  zone_name           = local.zone_name
  resource_group_name = local.dns_resource_group
  ttl                 = 30
  records             = [local.cluster_ips[each.key]]

  depends_on = [time_sleep.wait_after_destroy]

  lifecycle {
    create_before_destroy = false
  }
}

# Extmon-specific record
resource "azurerm_dns_a_record" "extmon" {
  for_each            = var.environment == "extmon" && anytrue([for c in var.clusters : c.active_cluster]) ? { "extmon" : true } : {}
  name                = "*.ext-mon"
  zone_name           = local.zone_name
  resource_group_name = local.dns_resource_group
  ttl                 = 30
  records             = [local.cluster_ips[keys({ for k, v in var.clusters : k => v if v.active_cluster })[0]]]

  depends_on = [time_sleep.wait_after_destroy]

  lifecycle {
    create_before_destroy = false
  }
}
