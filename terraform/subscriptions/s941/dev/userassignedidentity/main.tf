data "azuread_group" "radix_group" {
  display_name = local.external_outputs.global.outputs.globals.aad_radix_group
}

module "userassignedidentity" {
  source              = "../../../modules/userassignedidentity"
  name                = "id-radix-github-workflows-1-${local.external_outputs.clusters.outputs.clusters.enviroment}-test"
  resource_group_name = "${local.external_outputs.common.shared.resource_group}"
  location            = "${local.external_outputs.common.shared.location}"
}
