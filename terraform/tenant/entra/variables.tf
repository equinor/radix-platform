variable "sqlserver-admin-group" {
  type    = map(string)
  default = {
    dev        = "Radix SQL server admin - dev",
    playground = "Radix SQL server admin - playground",
    platform   = "Radix SQL server admin - platform",
    c2         = "Radix SQL server admin - c2",
    ext-mon    = "Radix SQL server admin - ext-mon",
  }
}
