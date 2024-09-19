module "config" {
  source = "../../../modules/config"
}

data "github_repository_file" "this" {
  repository = "equinor/radix-private"
  branch     = "master"
  file       = "terraform/privatelinks/${module.config.environment}.yaml"
}

module "resourcegroups" {
  source   = "../../../modules/resourcegroups"
  name     = module.config.vnet_resource_group
  location = module.config.location
}

module "azurerm_virtual_network" {
  source              = "../../../modules/virtualnetwork"
  location            = module.config.location
  enviroment          = module.config.environment
  vnet_resource_group = module.resourcegroups.data.name
  private_dns_zones   = tolist(module.config.private_dns_zones_names)
  depends_on          = [module.resourcegroups]
}

module "azurerm_public_ip_prefix_ingress" {
  source              = "../../../modules/network_publicipprefix"
  location            = module.config.location
  resource_group_name = var.resource_groups_common_temporary                                                #TODO
  publicipprefixname  = "ippre-ingress-radix-aks-${var.enviroment_temporary}-${module.config.location}-001" #TODO
  pipprefix           = "ingress-radix-aks"
  pippostfix          = module.config.location
  enviroment          = var.enviroment_temporary #TODO
  prefix_length       = 30
  zones               = ["1", "2", "3"]
}

module "azurerm_public_ip_prefix_egress" {
  source              = "../../../modules/network_publicipprefix"
  location            = module.config.location
  resource_group_name = var.resource_groups_common_temporary                                        #TODO
  publicipprefixname  = "ippre-radix-aks-${var.enviroment_temporary}-${module.config.location}-001" #TODO
  pipprefix           = "radix-aks"
  pippostfix          = module.config.location
  enviroment          = var.enviroment_temporary #TODO
  prefix_length       = 30
}


output "vnet_hub_id" {
  value = module.azurerm_virtual_network.data.vnet_hub.id
}

output "vnet_subnet_id" {
  value = module.azurerm_virtual_network.data.vnet_subnet.id
}

output "public_ip_prefix_ids" {
  value = {
    egress_id  = module.azurerm_public_ip_prefix_egress.data.id
    ingress_id = module.azurerm_public_ip_prefix_ingress.data.id
  }
}

module "private_endpoints" {
  source              = "../../../modules/private-endpoints"
  for_each            = yamldecode(data.github_repository_file.this.content)
  server_name         = each.key
  subresourcename     = each.value.subresourcename
  resource_id         = each.value.resource_id
  vnet_resource_group = module.resourcegroups.data.name
  manual_connection   = lookup(each.value, "manual_connection", false)
  depends_on          = [data.github_repository_file.this]
}


