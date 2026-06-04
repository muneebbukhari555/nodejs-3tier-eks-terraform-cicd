variable "name" {
  type        = string
  description = "Name of the addons module"
}
variable "region" {
  type        = string
  description = "AWS region"
}
variable "cluster_name" {
  type        = string
  description = "Name of the EKS cluster"
}
variable "vpc_id" {
  type        = string
  description = "ID of the VPC"
}
variable "oidc_provider_arn" {
  type        = string
  description = "ARN of the OIDC provider"
}

variable "lb_controller_chart_version" {
  type = string
}
variable "cluster_autoscaler_chart_version" {
  type = string
}
variable "metrics_server_chart_version" {
  type = string
}
variable "tags" {
  type    = map(string)
  default = {}
}
