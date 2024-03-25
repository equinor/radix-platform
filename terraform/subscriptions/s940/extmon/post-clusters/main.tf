module "config" {
  source = "../../../modules/config"
}

resource "local_file" "templates" {
  for_each = toset([
    for file in fileset(path.module, "templates/**") :      # The subfolder in current dir
    file if length(regexall(".*app-template.*", file)) == 0 # Ignore paths with "app-template"
  ])

  content = templatefile(each.key, {
    identity_id = data.azurerm_user_assigned_identity.this.client_id
  })

  filename = replace("${path.module}/${each.key}", "templates", "rendered")
}
