variable "publicipprefix" {
  type = map(object({
    zones = optional(list(string))

  }))
  default = {
    ingress-radix = {
      zones = ["1", "2", "3"]
    },
    radix = {
    }
  }
}
