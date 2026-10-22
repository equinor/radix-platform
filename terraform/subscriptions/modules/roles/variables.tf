variable "name" {
  description = "The name of the custom role."
  type        = string
}

variable "scope" {
  description = "The scope at which the role definition is created."
  type        = string
}

variable "description" {
  description = "A description of the custom role."
  type        = string
}

variable "actions" {
  description = "Management-plane actions granted by the role."
  type        = list(string)
  default     = []
}

variable "not_actions" {
  description = "Management-plane actions excluded from the role."
  type        = list(string)
  default     = []
}

variable "data_actions" {
  description = "Data-plane actions granted by the role."
  type        = list(string)
  default     = []
}

variable "not_data_actions" {
  description = "Data-plane actions excluded from the role."
  type        = list(string)
  default     = []
}

variable "assignable_scopes" {
  description = "Scopes where the custom role can be assigned."
  type        = list(string)
}