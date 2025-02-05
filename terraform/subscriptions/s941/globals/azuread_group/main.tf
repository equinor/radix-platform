data "azuread_group" "radix_platform_operators" {
  display_name     = "Radix Platform Operators"
  security_enabled = true
}

output "radix_platform_operators" {
  value = data.azuread_group.radix_platform_operators
}

data "azuread_group" "radix_platform_developers" {
  display_name     = "Radix Platform Developers"
  security_enabled = true
}

output "radix_platform_developers" {
  value = data.azuread_group.radix_platform_developers
}

data "azuread_group" "az_pim_omnia_radix_cluster_admin" {
  display_name     = "AZ PIM OMNIA RADIX Cluster Admin - dev"
  security_enabled = true
}


output "az_pim_omnia_radix_cluster_admin" {
  value = data.azuread_group.az_pim_omnia_radix_cluster_admin
}


data "azuread_group" "radix_sql_server_admins_dev" {
  display_name     = "Radix SQL server admin - dev"
  security_enabled = true
}

output "radix_sql_server_admins_dev" {
  value = data.azuread_group.radix_sql_server_admins_dev
}

data "azuread_group" "radix_sql_server_admins_playground" {
  display_name     = "Radix SQL server admin - playground"
  security_enabled = true
}

output "radix_sql_server_admins_playground" {
  value = data.azuread_group.radix_sql_server_admins_playground
}
