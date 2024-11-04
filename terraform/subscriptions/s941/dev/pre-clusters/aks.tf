module "aks" {
  source = "../../../modules/aks"
  # for_each            = { for k, v in jsondecode(nonsensitive(data.azurerm_key_vault_secret.this.value)).clusters : v.name => v.ip }
  for_each                = var.aksclusters
  cluster_name            = each.key
  resource_group          = module.config.cluster_resource_group
  location                = module.config.location
  subnet_id               = tolist(module.clusternetwork[each.key].vnet.subnet)[0].id
  dns_prefix              = "${each.key}-${module.config.cluster_resource_group}-${substr(module.config.subscription, 0, 6)}"
  autostartupschedule     = each.value.autostartupschedule
  migrationStrategy       = each.value.migrationStrategy
  outbound_ip_address_ids = each.value.outbound_ip_address_ids
  node_os_upgrade_channel = each.value.node_os_upgrade_channel
  depends_on = [ module.clusternetwork ]
}
