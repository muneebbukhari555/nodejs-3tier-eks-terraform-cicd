variable "name" { type = string }
variable "alb_dns_name" {
  type        = string
  default     = ""
  description = "Web ALB DNS name (empty disables CloudFront creation)"
}
variable "price_class" {
  type    = string
  default = "PriceClass_All"
}
variable "viewer_certificate_arn" {
  type        = string
  default     = ""
  description = "ACM cert ARN in us-east-1 for CloudFront viewer TLS (empty = default cert)"
}
variable "aliases" {
  type        = list(string)
  default     = []
  description = "Custom domain CNAMEs for the distribution"
}
variable "tags" {
  type    = map(string)
  default = {}
}
