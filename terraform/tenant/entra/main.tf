data "azuread_group" "radix-platform-developers" {
  display_name = "Radix Platform Developers"
  security_enabled = true
}

data "azuread_group" "radix-platform-operators" {
  display_name = "Radix Platform Operators"
  security_enabled = true
}
