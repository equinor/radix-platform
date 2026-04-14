# Wait 10 seconds before creating DNS records (after destroy)
resource "time_sleep" "wait_after_destroy" {
  create_duration = "10s"

  triggers = {
    cluster_ips = jsonencode({
      for k, v in var.clusters :
      k => v.dns_wildcard_type == "istio" ? v.istio_ip : v.nginx_ip
    })
    active_records = jsonencode(merge([
      for cluster_name, cluster in {
        for k, v in var.clusters :
        k => v if v.active_cluster && var.create_active_records
        } : {
        for record in ["@", "*", "*.app"] :
        "${cluster_name}-${record}" => {
          name    = record
          ip      = cluster.dns_wildcard_type == "istio" ? cluster.istio_ip : cluster.nginx_ip
          cluster = cluster_name
        }
      }
    ]...))
    active_clusters = jsonencode({
      for k, v in var.clusters :
      k => v if v.active_cluster && var.create_active_records
    })
  }
}

# Active cluster wildcard records
resource "azurerm_dns_a_record" "active" {
  for_each = merge([
    for cluster_name, cluster in {
      for k, v in var.clusters :
      k => v if v.active_cluster && var.create_active_records
      } : {
      for record in ["@", "*", "*.app"] :
      "${cluster_name}-${record}" => {
        name    = record
        ip      = cluster.dns_wildcard_type == "istio" ? cluster.istio_ip : cluster.nginx_ip
        cluster = cluster_name
      }
    }
  ]...)
  name                = each.value.name
  zone_name           = var.zone_name
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
  zone_name           = var.zone_name
  resource_group_name = var.dns_resource_group
  ttl                 = 30
  records             = [each.value.dns_wildcard_type == "istio" ? each.value.istio_ip : each.value.nginx_ip]

  depends_on = [time_sleep.wait_after_destroy]

  lifecycle {
    create_before_destroy = false
  }
}
