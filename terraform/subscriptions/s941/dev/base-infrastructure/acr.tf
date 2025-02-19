
module "acr" {
  source               = "../../../modules/acr"
  location             = module.config.location
  resource_group_name  = module.config.common_resource_group
  acr                  = module.config.environment
  vnet_resource_group  = module.config.vnet_resource_group
  subnet_id            = module.azurerm_virtual_network.azurerm_subnet_id
  dockercredentials_id = "/subscriptions/${module.config.subscription}/resourceGroups/${module.config.common_resource_group}/providers/Microsoft.ContainerRegistry/registries/radix${module.config.environment}cache/credentialSets/radix-service-account-docker"
  radix_cr_cicd        = replace(replace(module.app_application_registration.cr_cicd.azuread_service_principal_id, "/servicePrincipals/", ""), "/", "")
  retention_policy_env = 1
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
    radix-acr-cleanup-master = {
      name    = "radix-acr-cleanup-master"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-acr-cleanup:ref:refs/heads/master"
    },
    radix-cluster-cleanup-master = {
      name    = "radix-cluster-cleanup-master"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-cluster-cleanup:ref:refs/heads/master"
    },
    radix-cicd-canary-master = {
      name    = "radix-cicd-canary-master"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-cicd-canary:ref:refs/heads/master"
    },
    radix-vulnerability-scanner-main = {
      name    = "radix-vulnerability-scanner-main"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-vulnerability-scanner:ref:refs/heads/main"
    },
    radix-image-builder-master = {
      name    = "radix-image-builder-master"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-image-builder:ref:refs/heads/master"
    },
    radix-tekton-main = {
      name    = "radix-tekton-main"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-tekton:ref:refs/heads/main"
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
    radix-velero-plugin-master = {
      name    = "radix-velero-plugin-master"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-velero-plugin:ref:refs/heads/master"
    },
    radix-job-scheduler-main = {
      name    = "radix-job-scheduler-main"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-job-scheduler:ref:refs/heads/main"
    },
    radix-buildkit-builder-main = {
      name    = "radix-buildkit-builder-main"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-buildkit-builder:ref:refs/heads/main"
    },
  }
}


output "acr_id" {
  value = module.acr.azurerm_container_registry_id
}