locals {
  zone = {
    tenant_id            = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
    subscription_id      = "115a0693-7b56-4f35-8b25-7898d4b60cef"
    client_id            = "f1e6bc52-9aa4-4ca7-a9ac-b7a19d8f0f86"
    backend = {
      resource_group_name  = "s940-tfstate"
      storage_account_name = "s940radixinfra"
      container_name       = "infrastructure"
    }

    # object_ids = {
    #   fg_imdevops = "fdb6818e-f028-4534-a4a6-3093d1731e4e"
    # }
  }
}
