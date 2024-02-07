variable "sqlserver-developer-group" {
  type = map(string)
  default = {
    dev        = "Radix SQL server admin - dev",
    playground = "Radix SQL server admin - playground",
    ext-mon    = "Radix SQL server admin - ext-mon",
  }
}
variable "sqlserver-operators-group" {
  type = map(string)
  default = {
    platform = "Radix SQL server admin - platform",
    c2       = "Radix SQL server admin - c2",
  }
}
