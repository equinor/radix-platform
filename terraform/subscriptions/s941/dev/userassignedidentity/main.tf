data "azuread_group" "radix_group" {
  display_name = local.external_outputs.global.data.aad_radix_group
}

module "userassignedidentity" {
  source              = "../../../modules/userassignedidentity"
  name                = "id-radix-github-workflows-1-${local.external_outputs.clusters.data.enviroment}-test"
  resource_group_name = "${local.external_outputs.common.data.resource_group}"
  location            = "${local.external_outputs.common.data.location}"
}
