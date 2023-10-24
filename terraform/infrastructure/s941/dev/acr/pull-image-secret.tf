#provider "kubernetes" {
#  for_each = data.azurerm_kubernetes_cluster.k8s
#
#  host                   = each.value.kube_config.0.host
#  cluster_ca_certificate = base64decode(each.value.kube_config.0.cluster_ca_certificate)
#
#  client_certificate = base64decode(each.value.kube_config.0.client_certificate)
#  client_key         = base64decode(each.value.kube_config.0.client_key)
#}

#resource "azurerm_container_registry_scope_map" "scopemap" {
#  for_each = toset(var.K8S_ENVIROMENTS)
#
#  name                    = "buildah-cache-scope-map"
#  container_registry_name = azurerm_container_registry.acr[each.key].name
#  resource_group_name     = var.AZ_RESOURCE_GROUP_COMMON
#  actions                 = [
#    "repositories/*/content/read",
#    "repositories/*/content/write",
#    "repositories/*/content/delete"
#  ]
#}

resource "azurerm_container_registry_token" "acr" {
  for_each = toset(var.K8S_ENVIROMENTS)

  name                    = "buildah-cache-${each.key}"
  resource_group_name     = var.AZ_RESOURCE_GROUP_COMMON
  scope_map_id            = "${azurerm_container_registry.acr[each.key].id}/scopeMaps/_repositories_admin"
  # azurerm_container_registry_scope_map.scopemap[each.key].id
  container_registry_name = azurerm_container_registry.acr[each.key].name
}

resource "azurerm_container_registry_token_password" "password" {
  # Create one password for each environment to facilitate easier recovery and migration of cluster
  for_each = toset(var.K8S_ENVIROMENTS)

  container_registry_token_id = azurerm_container_registry_token.acr[each.key].id
  password1 {
    expiry = timeadd(plantimestamp(), var.ACR_TOKEN_LIFETIME)
  }

  #  lifecycle {
  #    ignore_changes = [password1["expiry"]]
  #  }
}

data "azurerm_key_vault" "vault" {
  for_each = toset(var.K8S_ENVIROMENTS)

  name                = var.key_vault_by_k8s_environment[each.key].name
  resource_group_name = var.key_vault_by_k8s_environment[each.key].rg_name
}

resource "azurerm_key_vault_secret" "secret" {
  for_each = toset(var.K8S_ENVIROMENTS)

  key_vault_id    = data.azurerm_key_vault.vault[each.key].id
  name            = "radix-buildah-repo-cache-secret-${each.key}"
  value           = azurerm_container_registry_token_password.password[each.key].password1[0].value
  expiration_date = timeadd(plantimestamp(), var.ACR_TOKEN_LIFETIME)
  tags            = {
    "rotate-strategy" = "Manually recreate password1 in ACR, then copy secret to cluster"
    "source-token"    = "buildah-cache-${each.key}"
    "source-acr"      = azurerm_container_registry.acr[each.key].name
  }

  #  lifecycle {
  #    ignore_changes = [expiration_date]
  #  }
}

locals {
  auth = {
    for k, v in data.azurerm_kubernetes_cluster.k8s : k =>{
      user = "buildah-cache-${local.clusterEnvironment[k]}",
      pass = azurerm_container_registry_token_password.password[local.clusterEnvironment[k]].password1[0].value
    }
  }

  k8sSecret = {
    for k, v in data.azurerm_kubernetes_cluster.k8s : k => {
      yaml = <<-EOF
        apiVersion: v1
        data:
          .dockerconfigjson: ${jsonencode({
              auths = {
                azurerm_container_registry.acr[local.clusterEnvironment[k]].login_server = {
                  "username" = local.auth[k].user
                  "password" = local.auth[k].pass
                  "email"    = "not@used.com"
                  "auth"     = base64encode("${local.auth[k].user}:${local.auth[k].pass}")
                }
              }
            })}
        kind: Secret
        metadata:
          name: radix-docker
          namespace: default
          annotations:
            kubed.appscode.com/syncTEST: "radix-env=appTEST"
        type: kubernetes.io/dockerconfigjson
        EOF
    }
  }
}

resource "null_resource" "create_token" {
  triggers = { always_run = "${timestamp()}" }
  for_each = data.azurerm_kubernetes_cluster.k8s

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "kubectl --kubeconfig <(echo ${base64encode(each.value.kube_config_raw)} | base64 --decode) apply -f <(echo ${base64encode(local.k8sSecret[each.key].yaml)} | base64 --decode)"
  }
}

#
#resource "kubernetes_secret" "secret" {
#  for_each = data.azurerm_kubernetes_cluster.k8s
#
#  metadata {
#    name      = "radix-cache-repo"
#    namespace = "default"
#  }
#
#  type = "kubernetes.io/dockerconfigjson"
#
#data = {
#  ".dockerconfigjson" = jsonencode({
#    auths = {
#      "${var.registry_server}" = {
#        "username" = "${each.key}-buildah"
#        "password" = azurerm_container_registry_token_password.password[each.key].password1
#        "email"    = "not@used.com"
#        "auth"     = base64encode("${var.registry_username}:${var.registry_password}")
#      }
#    }
#  })
#}
#
#  provisioner "kubernetes" {
#
#  }
#}


# kubectl create secret docker-registry richard-deleteme --docker-username=richard --docker-password=password --docker-email=not@used.com --docker-server=radixdevcache.azurecr.io
