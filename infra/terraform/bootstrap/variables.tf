variable "project" {
  type    = string
  default = "node3tier"
}
variable "region" {
  type    = string
  default = "us-east-2"
}

variable "github_owner" {
  type        = string
  description = "GitHub org/user that owns the repo"
}
variable "github_repo" {
  type        = string
  description = "Repository name (e.g. node-3tier-app2)"
}

variable "mgmt_vpc_cidr" {
  type    = string
  default = "10.1.0.0/16"
}
variable "mgmt_azs" {
  type    = list(string)
  default = ["us-east-2a", "us-east-2b"]
}

variable "runner_token_ssm_param" {
  type    = string
  default = "/node3tier/runner-registration-token"
}
variable "runner_image" {
  type        = string
  default     = "ghcr.io/actions/actions-runner:latest"
  description = "Runner container image (bundle terraform/kubectl/helm/docker/aws)"
}
variable "infra_runner_type" {
  type    = string
  default = "t3.medium"
}
variable "infra_runner_min" {
  type    = number
  default = 1
}
variable "infra_runner_max" {
  type    = number
  default = 3
}
variable "infra_runner_desired" {
  type    = number
  default = 1
}
variable "app_runner_type" {
  type    = string
  default = "t3.medium"
}
variable "app_runner_min" {
  type    = number
  default = 1
}
variable "app_runner_max" {
  type    = number
  default = 3
}
variable "app_runner_desired" {
  type    = number
  default = 1
}

# Broad policy for the infra runner. Scope down to the services Terraform
# manages for real production.
variable "infra_policy_arn" {
  type    = string
  default = "arn:aws:iam::aws:policy/AdministratorAccess"
}

variable "tags" {
  type = map(string)
  default = {
    Project   = "node3tier"
    ManagedBy = "terraform-bootstrap"
    Layer     = "foundation"
  }
}
