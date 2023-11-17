resource "azurerm_container_registry_token" "app_acr" {
  for_each = var.K8S_ENVIROMENTS

  name                    = "radix-app-registry-secret-${each.key}"
  resource_group_name     = var.AZ_RESOURCE_GROUP_COMMON
  scope_map_id            = "${azurerm_container_registry.app[each.key].id}/scopeMaps/_repositories_admin"
  container_registry_name = azurerm_container_registry.app[each.key].name

  depends_on = [azurerm_container_registry.app]
}

resource "azurerm_container_registry_token_password" "password" {
  for_each = var.K8S_ENVIROMENTS

  container_registry_token_id = azurerm_container_registry_token.app_acr[each.key].id
  password1 {
    expiry = timeadd(plantimestamp(), var.ACR_TOKEN_LIFETIME)
  }
}

data "azurerm_key_vault" "vault" {
  for_each = var.K8S_ENVIROMENTS

  name                = var.key_vault_by_k8s_environment[each.key].name
  resource_group_name = var.key_vault_by_k8s_environment[each.key].rg_name
}

resource "azurerm_key_vault_secret" "secret" {
  for_each = var.K8S_ENVIROMENTS

  key_vault_id    = data.azurerm_key_vault.vault[each.key].id
  name            = "radix-app-registry-secret-${each.key}"
  value           = azurerm_container_registry_token_password.password[each.key].password1[0].value
  expiration_date = timeadd(plantimestamp(), var.ACR_TOKEN_LIFETIME)
  tags            = {
    "rotate-strategy" = "Manually recreate password1 in ACR, then copy secret to cluster"
    "source-token"    = "radix-app-registry-secret-${each.key}"
    "source-acr"      = azurerm_container_registry.app[each.key].name
  }

  lifecycle { ignore_changes = [expiration_date] }
}

locals {
  auth = {
    for k, v in data.azurerm_kubernetes_cluster.k8s : k =>{
      server = azurerm_container_registry.app[local.clusterEnvironment[k]].login_server
      user   = "radix-app-registry-secret-${local.clusterEnvironment[k]}",
      pass   = azurerm_container_registry_token_password.password[local.clusterEnvironment[k]].password1[0].value
    }
  }

  nodeCount = {for k, v in data.azurerm_kubernetes_cluster.k8s : k => sum(v.agent_pool_profile[*].count)}

  config = {for k, v in data.azurerm_kubernetes_cluster.k8s : k => base64encode(v.kube_config_raw)}

  secret = {
    for k, v in data.azurerm_kubernetes_cluster.k8s : k => base64encode(<<-EOF
        apiVersion: v1
        data:
          username: ${base64encode(local.auth[k].user)}
          password: ${base64encode(local.auth[k].pass)}
        kind: Secret
        metadata:
          name: radix-app-registry
          namespace: default
        type: Opaque
        EOF
    )
  }
}

resource "null_resource" "create_token" {
  triggers = { always_run = azurerm_key_vault_secret.secret[local.clusterEnvironment[each.key]].expiration_date }

  # Dont try to exec on clusters that are off, it will fail
  for_each = {for k, v in data.azurerm_kubernetes_cluster.k8s : k => v if local.nodeCount[k] > 0}

  provisioner "local-exec" {
    interpreter = ["/bin/bash", "-c"]
    command     = "kubectl --kubeconfig <(echo ${local.config[each.key]} | base64 --decode) apply -f <(echo ${local.secret[each.key]} | base64 --decode)"
  }

}
