resource "azurerm_container_registry_token" "acr" {
  for_each = toset(var.K8S_ENVIROMENTS)

  name                    = "buildah-cache-${each.key}"
  resource_group_name     = var.AZ_RESOURCE_GROUP_COMMON
  scope_map_id            = "${azurerm_container_registry.acr[each.key].id}/scopeMaps/_repositories_admin"
  container_registry_name = azurerm_container_registry.acr[each.key].name
}

resource "azurerm_container_registry_token_password" "password" {
  for_each = toset(var.K8S_ENVIROMENTS)

  container_registry_token_id = azurerm_container_registry_token.acr[each.key].id
  password1 {
    expiry = timeadd(plantimestamp(), var.ACR_TOKEN_LIFETIME)
  }
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
}

locals {
  auth = {
    for k, v in data.azurerm_kubernetes_cluster.k8s : k =>{
      server = azurerm_container_registry.acr[local.clusterEnvironment[k]].login_server
      user   = "buildah-cache-${local.clusterEnvironment[k]}",
      pass   = azurerm_container_registry_token_password.password[local.clusterEnvironment[k]].password1[0].value
    }
  }

  config = {for k, v in data.azurerm_kubernetes_cluster.k8s : k => base64encode(v.kube_admin_config_raw)}

  secret = {
    for k, v in data.azurerm_kubernetes_cluster.k8s : k => base64encode(<<-EOF
        apiVersion: v1
        data:
          .dockerconfigjson: ${base64encode(jsonencode({
              auths = {
                local.auth[k].server = {
                  "username" = local.auth[k].user
                  "password" = local.auth[k].pass
                  "email"    = "not@used.com"
                  "auth"     = base64encode("${local.auth[k].user}:${local.auth[k].pass}")
                }
              }
            }))}
        kind: Secret
        metadata:
          name: radix-buildah-cache-repo
          namespace: default
          annotations:
            kubed.appscode.com/sync: "radix-env=app"
        type: kubernetes.io/dockerconfigjson
        EOF
    )
  }
}

resource "null_resource" "create_token" {
  triggers = { always_run = "${timestamp()}" }
  for_each = data.azurerm_kubernetes_cluster.k8s

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "kubectl --kubeconfig <(echo ${local.config[each.key]} | base64 --decode) apply -f <(echo ${local.secret[each.key]} | base64 --decode)"
  }
}
