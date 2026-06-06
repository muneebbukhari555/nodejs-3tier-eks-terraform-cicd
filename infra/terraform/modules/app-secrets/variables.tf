variable "secret_prefix" {
  type        = string
  description = "Prepended to each secret name. E.g. 'node3tier-prod/' → 'node3tier-prod/api'."
}

variable "secrets" {
  type = map(object({
    description = string
  }))
  description = "Map of secrets to create. Key becomes the secret name suffix."
  default = {
    api = { description = "App-level secrets for the api service" }
    web = { description = "App-level secrets for the web service" }
  }
}

variable "recovery_window_days" {
  type    = number
  default = 7
}

variable "tags" {
  type    = map(string)
  default = {}
}
