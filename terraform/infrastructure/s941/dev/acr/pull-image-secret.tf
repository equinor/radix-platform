#provider "kubernetes" {
#  for_each = data.azurerm_kubernetes_cluster.k8s
#
#  host                   = each.value.kube_config.0.host
#  cluster_ca_certificate = base64decode(each.value.kube_config.0.cluster_ca_certificate)
#
#  client_certificate = base64decode(each.value.kube_config.0.client_certificate)
#  client_key         = base64decode(each.value.kube_config.0.client_key)
#}

resource "azurerm_container_registry_scope_map" "scopemap" {
  for_each = data.azurerm_kubernetes_cluster.k8s

  name                    = "buildah-scope-map"
  container_registry_name = "radix${azurerm_container_registry.acr[local.clusterEnvironment[each.key]].name}cache"
  resource_group_name     = var.AZ_RESOURCE_GROUP_COMMON
  actions                 = [
    "content/read",
    "content/write",
    "content/delete"
  ]
}

resource "azurerm_container_registry_token" "acr" {
  for_each = data.azurerm_kubernetes_cluster.k8s

  name                    = "${each.key}-buildah"
  resource_group_name     = var.AZ_RESOURCE_GROUP_COMMON
  scope_map_id            = azurerm_container_registry_scope_map.scopemap[each.key].id
  container_registry_name = "radix${azurerm_container_registry.acr[local.clusterEnvironment[each.key]].name}cache"
}

resource "azurerm_container_registry_token_password" "password" {
  for_each = data.azurerm_kubernetes_cluster.k8s

  container_registry_token_id = azurerm_container_registry_token.acr[each.key].id
  password1 {}
}

#resource "kubernetes_secret" "secret" {
#  for_each = data.azurerm_kubernetes_cluster.k8s
#
#  metadata {
#    name      = "radix-cache-repo"
#    namespace = "default"
#  }
#
#  data = {
#    username = "${each.key}-buildah"
#    password = azurerm_container_registry_token_password.password[each.key].password1
#  }
#
#  type = "kubernetes.io/basic-auth"
#}
#
