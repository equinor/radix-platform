resource "local_file" "templates" {
  for_each = toset([
    for file in fileset(path.module, "templates/**") : # The subfolder in current dir
    file if length(regexall(".*radix.*", file)) == 0   # Ignore paths with "radix"
  ])

  content = templatefile(each.key, {
    prefix                 = "$"
    tenant_id              = var.tenant_id
    subscription_id        = var.subscription_id
    subscription_shortname = var.subscription_shortname
    sourcezone             = var.sourcezone
    sourcelocation         = var.sourcelocation
    destinationzone        = var.destinationzone
    location               = var.location

  })

  filename = replace("${path.module}/${each.key}", "templates", "../../subscriptions/${var.subscription_shortname}/${var.zone}")
}

