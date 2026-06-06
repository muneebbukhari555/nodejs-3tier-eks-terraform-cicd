variable "name" {
  type        = string
  description = "Project name prefix used for IAM resource naming."
}

variable "region" {
  type        = string
  description = "AWS region where Secrets Manager / SSM entries live."
}

variable "cluster_name" {
  type        = string
  description = "EKS cluster name (informational; used for tagging)."
}

variable "oidc_provider_arn" {
  type        = string
  description = "EKS OIDC provider ARN (module.eks.oidc_provider_arn)."
}

variable "namespace" {
  type        = string
  default     = "external-secrets"
  description = "Kubernetes namespace to install the operator into."
}

variable "chart_version" {
  type        = string
  default     = "0.10.7"
  description = <<-EOT
    Helm chart version for external-secrets.
    Check https://github.com/external-secrets/external-secrets/releases
    and update to the latest stable before deploying.
  EOT
}

variable "cluster_secret_store_name" {
  type        = string
  default     = "aws-secrets-manager"
  description = "Name of the ClusterSecretStore resource created in-cluster."
}

variable "secret_prefix" {
  type        = string
  default     = ""
  description = <<-EOT
    IAM resource prefix for Secrets Manager and SSM Parameter Store.
    Secrets starting with this string are readable by the operator.
    Leave empty to allow access to all secrets (not recommended for prod).
    Example: "node3tier/" scopes access to secrets like "node3tier/db-password".
  EOT
}

variable "tags" {
  type    = map(string)
  default = {}
}
