resource "azurerm_network_security_group" "this" {
  name                = var.nsg_name
  location            = var.location
  resource_group_name = var.resource_group

  tags = {
    IaC = "terraform"
  }
}

resource "azurerm_virtual_network" "this" {
  name                = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group
  address_space       = ["${var.address_space}/16"]

  dynamic "ddos_protection_plan" {
    for_each = var.enable_ddos_protection_plan ? [1] : []
    content {
      enable = true
      id     = var.ddos_protection_plan_id
    }

  }

  tags = {
    IaC = "terraform"
  }
}

resource "azurerm_subnet" "this" {
  name                            = var.subnet_name
  resource_group_name             = var.resource_group
  virtual_network_name            = azurerm_virtual_network.this.name
  address_prefixes                = ["${var.address_space}/18"]
  default_outbound_access_enabled = true
}

resource "azurerm_subnet_network_security_group_association" "this" {
  subnet_id                 = azurerm_subnet.this.id
  network_security_group_id = azurerm_network_security_group.this.id
  depends_on                = [azurerm_virtual_network.this]
}


resource "azurerm_management_lock" "network" {
  for_each   = var.enable_network_lock ? { "${azurerm_virtual_network.this.name}" : true } : {}
  name       = var.network_lock_name
  scope      = azurerm_virtual_network.this.id
  lock_level = "CanNotDelete"
  notes      = "IaC : Terraform"
}

output "vnet" {
  value = azurerm_virtual_network.this
}

output "subnet" {
  value = azurerm_subnet.this
}

resource "azurerm_virtual_network_peering" "hub_to_cluster" {
  name                      = var.hub_to_cluster_peering_name
  resource_group_name       = var.cluster_vnet_resourcegroup
  virtual_network_name      = var.hub_virtual_network_name
  remote_virtual_network_id = azurerm_virtual_network.this.id
  allow_forwarded_traffic   = true
  local_subnet_names        = []
  only_ipv6_peering_enabled = false
  remote_subnet_names       = []
}

resource "azurerm_virtual_network_peering" "cluster_to_hub" {
  name                      = var.cluster_to_hub_peering_name
  resource_group_name       = var.cluster_to_hub_resource_group
  virtual_network_name      = var.vnet_name
  remote_virtual_network_id = var.vnethub_id
  allow_forwarded_traffic   = true
  local_subnet_names        = []
  only_ipv6_peering_enabled = false
  remote_subnet_names       = []
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each              = toset(var.dnszones)
  name                  = var.private_dns_zone_link_name
  resource_group_name   = var.cluster_vnet_resourcegroup
  private_dns_zone_name = each.value
  virtual_network_id    = azurerm_virtual_network.this.id
}