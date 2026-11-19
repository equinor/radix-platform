module "ampls" {
  count                                = var.ampls_enabled ? 1 : 0
  source                               = "../ampls"
  ampls_name                           = var.ampls_name
  location                             = var.location
  private_dns_zones                    = var.virtual_network_private_dns_zone
  private_endpoint_name                = var.ampls_private_endpoint_name
  private_endpoint_resource_group_name = var.vnet_resource_group
  resource_group_name                  = var.ampls_resource_group
  subnet_id                            = var.virtual_network_subnet_id
}
