module "network_security_perimeter" {
  source                          = "../network_security_perimeter"
  network_security_perimeter_name = var.network_security_perimeter_name
  resource_group_name             = var.network_security_perimeter_resource_group_name
  location                        = var.location
  associations                    = var.network_security_perimeter_associations
}

