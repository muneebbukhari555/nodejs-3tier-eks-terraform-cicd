variable "name" {
  type        = string
  description = "Resource name prefix, e.g. node3tier-infra or node3tier-app"
}
variable "region" { type = string }

variable "vpc_id" { type = string }
variable "subnet_ids" {
  type        = list(string)
  description = "PRIVATE mgmt-VPC subnets the runners launch in (egress via NAT)"
}

variable "github_url" {
  type        = string
  description = "https://github.com/<owner>/<repo> the runners register to"
}
variable "runner_token_ssm_param" {
  type        = string
  description = "SSM SecureString param holding a GitHub App-generated token / PAT with repo admin (used only to fetch a registration token)"
}
variable "runner_labels" {
  type        = string
  description = "Comma-separated runner labels, e.g. self-hosted,linux,infra"
}
variable "runner_image" {
  type        = string
  default     = "ghcr.io/actions/actions-runner:latest"
  description = "Container image with the runner + bundled tools"
}

variable "instance_type" {
  type = string
}
variable "min_size" {
  type    = number
  default = 0
}
variable "max_size" {
  type    = number
  default = 4
}
variable "desired_capacity" {
  type    = number
  default = 1
}

# Least-privilege IAM for this fleet. SSM core + ECR auth are always attached;
# pass the fleet-specific permissions here.
variable "managed_policy_arns" {
  type    = list(string)
  default = []
}
variable "inline_policy_json" {
  type    = string
  default = ""
}
# Must be known at plan time (the JSON above usually comes from a data source,
# which is unknown until apply, so we can't use it in count).
variable "create_inline_policy" {
  type    = bool
  default = false
}

variable "tags" {
  type    = map(string)
  default = {}
}
