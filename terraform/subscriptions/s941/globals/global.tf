locals {
  globals = {
    tenant_id       = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
    subscription_id = "16ede44b-1f74-40a5-b428-46cca9a5741b"
    client_id       = "f1e6bc52-9aa4-4ca7-a9ac-b7a19d8f0f86"
    aad_radix_group = "radix"
    github_repos = {
      "radix_canary" : ["release", "master"],
      "radix_cost-allocation1" : ["release"]
      "radix_cost-allocation2" : ["release"]
      "radix_cost-allocation3" : ["release"]
      "radix_cost-allocation4" : ["release"]
      "radix_cost-allocation5" : ["release"]
      "radix_cost-allocation6" : ["release"]
      "radix_cost-allocation7" : ["release"]
      "radix_cost-allocation8" : ["release"]
      "radix_cost-allocation9" : ["release"]
      "radix_cost-allocation10" : ["release"]
      "radix_cost-allocation11" : ["release"]
      "radix_cost-allocation12" : ["release"]
      "radix_cost-allocation13" : ["release"]
      "radix_cost-allocation14" : ["release"]
      "radix_cost-allocation15" : ["release"]
      "radix_cost-allocation16" : ["release"]
      "radix_cost-allocation17" : ["release"]
      "radix_cost-allocation18" : ["release"]
      "radix_cost-allocation19" : ["release"]
      "radix_cost-allocation20" : ["release"]
      "radix_cost-allocation21" : ["release"]
    }
    backend = {
      resource_group_name  = "s941-tfstate"
      storage_account_name = "s941radixinfra"
      container_name       = "infrastructure"
    }
  }
}
