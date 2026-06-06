variable "domain_name" {
  type        = string
  default     = ""
  description = "App domain (e.g. app.example.com). Empty disables ACM."
}
variable "zone_id" {
  type        = string
  default     = ""
  description = "Route 53 hosted zone ID for DNS validation."
}
variable "tags" {
  type    = map(string)
  default = {}
}
