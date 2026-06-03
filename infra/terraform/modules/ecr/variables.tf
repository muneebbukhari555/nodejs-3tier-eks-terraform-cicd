variable "name" { type = string }
variable "repositories" {
  type        = list(string)
  description = "Repository short names (e.g. web, api)"
  default     = ["web", "api"]
}
variable "keep_last" {
  type    = number
  default = 20
}
variable "tags" {
  type    = map(string)
  default = {}
}
