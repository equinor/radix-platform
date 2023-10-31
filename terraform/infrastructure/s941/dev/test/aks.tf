resource "azurerm_kubernetes_cluster" "test" {
  location            = azurerm_resource_group.test.location
  name                = "rihag-test-deleteme"
  resource_group_name = azurerm_resource_group.test.name
  dns_prefix          = "rihag-tet"

  kubernetes_version = "1.26"

  identity {
    type = "SystemAssigned"
  }

  default_node_pool {
    name       = "test"
    vm_size    = "Standard_B4ms"
    node_count = 1
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "test" {
  kubernetes_cluster_id = azurerm_kubernetes_cluster.test.id
  name                  = "user"
  vm_size               = "Standard_B4ms"
  node_count            = 1
}
