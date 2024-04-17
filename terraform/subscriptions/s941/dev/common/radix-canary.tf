module "canary-mi-master" {
  source   = "../../../modules/userassignedidentity"
  name     = "id-radix-github-workflows-radix-canary-master"
  resource_group_name = "common" // TODO: MI should move to correct resource group module.config.common_resource_group
  location = module.config.location

  federated_credentials = {
    master = {
      name    = "radix-canary-master"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-canary:ref:refs/heads/master"
    }
  }
}
module "canary-mi-release" {
  source   = "../../../modules/userassignedidentity"
  name     = "id-radix-github-workflows-radix-canary-release"
  resource_group_name = "common" // TODO: MI should move to correct resource group module.config.common_resource_group
  location = module.config.location
  federated_credentials = {
    release = {
      name    = "radix-canary-release"
      issuer  = "https://token.actions.githubusercontent.com"
      subject = "repo:equinor/radix-canary:ref:refs/heads/release"
    }
  }
}
