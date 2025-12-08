resource "azurerm_network_security_group" "this" {
  name                = "nsg-${var.cluster_name}"
  location            = var.location
  resource_group_name = var.resource_group

  security_rule {
    access                     = "Allow"
    destination_address_prefix = var.ingressIP
    destination_port_ranges    = ["80", "443"]
    direction                  = "Inbound"
    name                       = "nsg-${var.cluster_name}-nginx-LB"
    priority                   = 100
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
  }

  security_rule {
    access                     = "Allow"
    destination_address_prefix = var.istioIP
    destination_port_ranges    = ["80", "443"]
    direction                  = "Inbound"
    name                       = "nsg-${var.cluster_name}-istio-LB"
    priority                   = 101
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
  }

  security_rule {
    access                     = "Deny"
    destination_address_prefix = "*"
    destination_port_ranges    = ["22"]
    direction                  = "Inbound"
    name                       = "Deny-ssh"
    priority                   = 110
    protocol                   = "Tcp"
    source_address_prefix      = "*"
    source_port_range          = "*"
  }

  tags = {
    IaC = "terraform"
  }
}

data "azurerm_network_watcher" "this" {
  name                = "NetworkWatcher_${var.location}"
  resource_group_name = "NetworkWatcherRG"
}

resource "azapi_resource" "vnet_flow_logs" {
  type      = "Microsoft.Network/networkWatchers/flowLogs@2023-11-01"
  name      = "${azurerm_virtual_network.this.name}-logs"
  location  = data.azurerm_network_watcher.this.location
  parent_id = data.azurerm_network_watcher.this.id
  tags = {
    IaC = "terraform"
  }

  body = {
    properties = {
      enabled = true
      flowAnalyticsConfiguration = {
        networkWatcherFlowAnalyticsConfiguration = {
          enabled = false
        }
      }
      format = {
        type    = "JSON"
        version = 2
      }
      retentionPolicy = {
        days    = 90
        enabled = true
      }
      storageId        = var.storageaccount_id
      targetResourceId = azurerm_virtual_network.this.id
    }
  }
}

resource "azurerm_virtual_network" "this" {
  name                = "vnet-${var.cluster_name}"
  location            = var.location
  resource_group_name = var.resource_group
  address_space       = ["${var.address_space}/16"]

  dynamic "ddos_protection_plan" {
    for_each = var.enviroment == "platform" || var.enviroment == "c2" ? [1] : []
    content {
      enable = true
      id     = "/subscriptions/ded7ca41-37c8-4085-862f-b11d21ab341a/resourceGroups/rg-protection-we/providers/Microsoft.Network/ddosProtectionPlans/ddos-protection"
    }

  }

  tags = {
    IaC = "terraform"
  }
}

resource "azurerm_subnet" "this" {
  name                            = "subnet-${var.cluster_name}"
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
  for_each   = var.enviroment == "platform" || var.enviroment == "c2" ? { "${azurerm_virtual_network.this.name}" : true } : {}
  name       = "${azurerm_virtual_network.this.name}-CanNotDelete-Lock"
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
  name                      = "hub-to-vnet-${var.cluster_name}" == "hub-to-vnet-c2-11" ? "vnet-hub-to-c2-11" : "hub-to-vnet-${var.cluster_name}"
  resource_group_name       = var.cluster_vnet_resourcegroup
  virtual_network_name      = "vnet-hub"
  remote_virtual_network_id = azurerm_virtual_network.this.id
  allow_forwarded_traffic   = true
  local_subnet_names        = []
  only_ipv6_peering_enabled = false
  remote_subnet_names       = []
}

resource "azurerm_virtual_network_peering" "cluster_to_hub" {
  name                      = "vnet-${var.cluster_name}-to-hub" == "vnet-c2-11-to-hub" ? "c2-11-to-vnet-hub" : "vnet-${var.cluster_name}-to-hub"
  resource_group_name       = "clusters-${var.enviroment}" == "clusters-platform" ? "clusters" : "clusters-${var.enviroment}"
  virtual_network_name      = "vnet-${var.cluster_name}"
  remote_virtual_network_id = var.vnethub_id
  allow_forwarded_traffic   = true
  local_subnet_names        = []
  only_ipv6_peering_enabled = false
  remote_subnet_names       = []
}

resource "azurerm_private_dns_zone_virtual_network_link" "this" {
  for_each              = toset(var.dnszones)
  name                  = "${var.cluster_name}-link"
  resource_group_name   = var.cluster_vnet_resourcegroup
  private_dns_zone_name = each.value
  virtual_network_id    = azurerm_virtual_network.this.id
}