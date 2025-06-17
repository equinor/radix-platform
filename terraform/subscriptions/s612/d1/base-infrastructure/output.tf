output "az_resource_group_clusters" {
  value = module.radix_base.az_resource_group_clusters
}

output "az_resource_group_common" {
  value = module.radix_base.az_resource_group_common
}

output "velero_storage_account" {
  value = module.radix_base.velero_storage_account
}

output "keyvault_name" {
  value = module.radix_base.keyvault_name
}

output "dns_zone_name" {
  value = module.radix_base.dns_zone_name
}

output "imageRegistry" {
  value = module.radix_base.imageRegistry
}

output "public_ip_prefix_names" {
  value = {
    egress  = module.radix_base.public_ip_prefix_names.egress
    ingress = module.radix_base.public_ip_prefix_names.ingress
  }
}
