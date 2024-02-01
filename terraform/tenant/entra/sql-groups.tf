data "azuread_group" "mssql-admin" {
  for_each = var.sqlserver-admin-group

  display_name = each.value
  security_enabled = true
}

resource "azuread_group_member" "msqladmin-member" {
 for_each = data.azuread_group.mssql-admin

  group_object_id  = each.value.object_id
  member_object_id = data.azuread_group.radix-platform-developers.object_id
}
