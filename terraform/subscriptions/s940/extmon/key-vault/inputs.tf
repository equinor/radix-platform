locals {

  ## Backend Config
  backend = {
    resource_group_name  = "s940-tfstate"
    storage_account_name = "s940radixinfra"
    container_name       = "infrastructure"
    subscription_id      = "ded7ca41-37c8-4085-862f-b11d21ab341a"
  }
}
