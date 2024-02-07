data "azuread_group" "mssql-operators" {
  for_each = var.sqlserver-operators-group

  display_name     = each.value
  security_enabled = true
}

resource "azuread_group_member" "msqladmin-operators" {
  for_each = data.azuread_group.mssql-operators

  group_object_id  = each.value.object_id
  member_object_id = data.azuread_group.radix-platform-operators.object_id
}



data "azuread_group" "mssql-developers" {
  for_each = var.sqlserver-developer-group

  display_name     = each.value
  security_enabled = true
}
resource "azuread_group_member" "msqladmin-developers" {
  for_each = data.azuread_group.mssql-developers

  group_object_id  = each.value.object_id
  member_object_id = data.azuread_group.radix-platform-developers.object_id
}
