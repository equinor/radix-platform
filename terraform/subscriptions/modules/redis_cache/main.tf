resource "azurerm_redis_cache" "this" {
  for_each                      = toset(["qa", "prod"])
  name                          = "${var.name}-${each.key}"
  location                      = var.location
  resource_group_name           = var.rg_name
  capacity                      = 1
  family                        = "C"
  sku_name                      = var.sku_name
  minimum_tls_version           = "1.2"
  public_network_access_enabled = false
  redis_configuration {
    maxmemory_reserved                     = 125
    maxmemory_delta                        = 125
    maxfragmentationmemory_reserved        = 125
    data_persistence_authentication_method = "SAS"

    maxmemory_policy = "volatile-lru"
  }
}