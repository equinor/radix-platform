module "nsg" {
  
  source                     = "../../../modules/networksecuritygroup"
  networksecuritygroupname   = "nsg-weekly-50"
  location                   = local.output.location
  resource_group_name        = local.output.resource_group
  destination_address_prefix = "20.223.40.151"
}
