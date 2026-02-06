data "azurerm_network_security_group" "this" {
  for_each            = var.nsg_ids
  name                = each.key
  resource_group_name = var.resource_group_name
}

data "azurerm_public_ip" "gateway_pip" {
  for_each            = local.nsg_to_gateway_pip
  name                = each.value
  resource_group_name = var.resource_group_name == "clusters" ? "clusters-platform" : var.resource_group_name # TODO should be in the same RG as NSG
}

locals {
  # Map cluster name to networkset name
  cluster_to_networkset = {
    for cluster_name, cluster_config in var.clusters :
    cluster_name => cluster_config.networkset
  }

  # Map cluster name to gatewayPIP name
  cluster_to_gateway_pip = {
    for cluster_name, cluster_config in var.clusters :
    cluster_name => var.networksets[cluster_config.networkset].gatewayPIP
  }

  # Map NSG name to cluster name (assuming pattern nsg-<cluster-name>)
  nsg_to_cluster = {
    for nsg_name in keys(data.azurerm_network_security_group.this) :
    nsg_name => replace(nsg_name, "nsg-", "")
  }

  # Map NSG name to gatewayPIP name
  nsg_to_gateway_pip = {
    for nsg_name, cluster_name in local.nsg_to_cluster :
    nsg_name => local.cluster_to_gateway_pip[cluster_name]
    if try(var.networksets[local.cluster_to_networkset[cluster_name]].gatewayPIP, null) != null
  }

  # Extract the IP addresses from the public IP resources
  istio_lb_ips = {
    for nsg_name in keys(local.nsg_to_gateway_pip) :
    nsg_name => data.azurerm_public_ip.gateway_pip[nsg_name].ip_address
  }

  # Extract the ingressIP from the networkset for nginx
  nginx_lb_ips = {
    for nsg_name, cluster_name in local.nsg_to_cluster :
    nsg_name => var.networksets[local.cluster_to_networkset[cluster_name]].ingressIP
    if try(var.networksets[local.cluster_to_networkset[cluster_name]].ingressIP, null) != null
  }
}

resource "azurerm_network_security_rule" "nginx" {
  for_each                    = local.nginx_lb_ips
  name                        = "${each.key}-nginx"
  priority                    = 100
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefix       = "*"
  destination_address_prefix  = each.value
  resource_group_name         = data.azurerm_network_security_group.this[each.key].resource_group_name
  network_security_group_name = data.azurerm_network_security_group.this[each.key].name
  description                 = "IaC = Terraform"
}

resource "azurerm_network_security_rule" "istio" {
  for_each                    = local.istio_lb_ips
  name                        = "${each.key}-istio"
  priority                    = 110
  direction                   = "Inbound"
  access                      = "Allow"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_ranges     = ["80", "443"]
  source_address_prefix       = "*"
  destination_address_prefix  = each.value
  resource_group_name         = data.azurerm_network_security_group.this[each.key].resource_group_name
  network_security_group_name = data.azurerm_network_security_group.this[each.key].name
  description                 = "IaC = Terraform"
}

resource "azurerm_network_security_rule" "ssh" {
  for_each                    = data.azurerm_network_security_group.this
  name                        = "Deny-ssh"
  priority                    = 199
  direction                   = "Inbound"
  access                      = "Deny"
  protocol                    = "Tcp"
  source_port_range           = "*"
  destination_port_range      = "22"
  source_address_prefix       = "*"
  destination_address_prefix  = "*"
  resource_group_name         = data.azurerm_network_security_group.this[each.key].resource_group_name
  network_security_group_name = data.azurerm_network_security_group.this[each.key].name
  description                 = "IaC = Terraform"
}
