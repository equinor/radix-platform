module "acr" {
  source               = "../../../modules/acr"
  location             = module.config.location
  resource_group_name  = module.resourcegroup_common.data.name
  acr                  = "prod" #TODO
  vnet_resource_group  = module.azurerm_virtual_network.data.vnet_hub.resource_group_name
  subnet_id            = module.azurerm_virtual_network.data.vnet_subnet.id
  keyvault_name        = module.keyvault.vault_name
  dockercredentials_id = "/subscriptions/${module.config.subscription}/resourceGroups/${module.config.common_resource_group}/providers/Microsoft.ContainerRegistry/registries/radix${module.config.environment}cache/credentialSets/radix-service-account-docker"
  radix_cr_cicd        = replace(replace(module.app_application_registration.cr_cicd.azuread_service_principal_id, "/servicePrincipals/", ""), "/", "")
  secondary_location   = module.config.secondary_location
  depends_on           = [module.azurerm_virtual_network]
}

module "radix-id-acr-workflows" {
  source              = "../../../modules/userassignedidentity"
  name                = "radix-id-acr-workflows-${module.config.environment}"
  resource_group_name = module.config.common_resource_group
  location            = module.config.location
  roleassignments = {
    contributor = {
      role     = "Contributor" # Needed to open firewall
      scope_id = module.acr.azurerm_container_registry_id
    },
    acrpush = {
      role     = "AcrPush"
      scope_id = module.acr.azurerm_container_registry_id
    }
  }
  federated_credentials = {
    radix-acr-cleanup-release = {
      name    = "radix-acr-cleanup-release"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-acr-cleanup:ref:refs/heads/release"
    },
    radix-cluster-cleanup-release = {
      name    = "radix-cluster-cleanup-release"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-cluster-cleanup:ref:refs/heads/release"
    },
    radix-cicd-canary-release = {
      name    = "radix-cicd-canary-release"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-cicd-canary:ref:refs/heads/release"
    },
    radix-vulnerability-scanner-release = {
      name    = "radix-vulnerability-scanner-release"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-vulnerability-scanner:ref:refs/heads/release"
    },
    radix-image-builder-release = {
      name    = "radix-image-builder-release"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-image-builder:ref:refs/heads/release"
    },
    radix-tekton-release = {
      name    = "radix-tekton-release"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-tekton:ref:refs/heads/release"
    },
    radix-operator-master = {
      name    = "radix-operator-master"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-operator:ref:refs/heads/master"
    },
    radix-operator-release = {
      name    = "radix-operator-release"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-operator:ref:refs/heads/release"
    },
    radix-velero-plugin-release = {
      name    = "radix-velero-plugin-release"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-velero-plugin:ref:refs/heads/release"
    },
    radix-job-scheduler-release = {
      name    = "radix-job-scheduler-release"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-job-scheduler:ref:refs/heads/release"
    },
    radix-buildkit-builder-release = {
      name    = "radix-buildkit-builder-release"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-buildkit-builder:ref:refs/heads/release"
    },
  }
}

output "imageRegistry" {
  value = module.acr.azurerm_container_registry_env_login_server
}