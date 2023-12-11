## Shared Values
# NOTE: Local shared values are needed as this module can not import its own outputs,
# NOTE: The shared output resource has a reference to this object.
locals {
  shared = {
    subscription_id           = "16ede44b-1f74-40a5-b428-46cca9a5741b"
    tenant_id                 = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
    location                  = "northeurope"
    AZ_SUBSCRIPTION_SHORTNAME = "s941"
    subscription_shortname    = "s941"
    resource_group            = "common"
  }
}
