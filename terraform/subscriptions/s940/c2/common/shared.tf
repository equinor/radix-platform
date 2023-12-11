## Shared Values
# NOTE: Local shared values are needed as this module can not import its own outputs,
# NOTE: The shared output resource has a reference to this object.
locals {
  shared = {
    subscription_id           = "ded7ca41-37c8-4085-862f-b11d21ab341a"
    tenant_id                 = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
    location                  = "westeurope"
    AZ_SUBSCRIPTION_SHORTNAME = "s940"
    subscription_shortname    = "s940"
  }
}
