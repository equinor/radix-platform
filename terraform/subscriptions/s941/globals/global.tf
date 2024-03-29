locals {

  outputs = {
    tenant_id              = "3aa4a235-b6e2-48d5-9195-7fcf05b459b0"
    subscription_id        = "16ede44b-1f74-40a5-b428-46cca9a5741b"
    client_id              = "f1e6bc52-9aa4-4ca7-a9ac-b7a19d8f0f86"
    subscription_shortname = "s941"
    aad_radix_group        = "radix"
    gh_repos               = local.gh_repos
    gh_repo_branch_combinations = { for item in flatten([
      for repo, branches in local.gh_repos : [
        for branch in branches : {
          name   = "${repo}-${branch}"
          repo   = repo
          branch = branch
        }
      ]
    ]) : item.name => item }
    # resourcegroups = module.resourcegroups
  }
}
