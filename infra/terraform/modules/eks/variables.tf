variable "name" {
  type = string
}
variable "cluster_version" {
  type = string
}
variable "vpc_id" {
  type = string
}
variable "private_subnets" {
  type = list(string)
}
variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}
variable "node_min_size" {
  type    = number
  default = 2
}
variable "node_max_size" {
  type    = number
  default = 4
}
variable "node_desired_size" {
  type    = number
  default = 2
}
variable "node_ami_type" {
  type    = string
  default = "AL2023_x86_64_STANDARD"
}
variable "node_capacity_type" {
  type        = string
  default     = "ON_DEMAND"
  description = "ON_DEMAND or SPOT"
}
variable "node_disk_size" {
  type    = number
  default = 30
}
# Optional k8s version override for the node group (defaults to cluster_version).
variable "node_kubernetes_version" {
  type    = string
  default = null
}
variable "addon_versions" {
  type    = map(string)
  default = {}
}
variable "endpoint_private_access" {
  type        = bool
  default     = true
  description = "Expose the EKS API on the private endpoint (in-VPC)."
}
variable "api_allowed_cidrs" {
  type        = list(string)
  default     = []
  description = "CIDRs allowed to reach the private API (mgmt VPC + workload VPC)"
}
variable "cluster_admin_principal_arns" {
  type        = list(string)
  default     = []
  description = "IAM role ARNs granted cluster-admin via EKS access entries"
}
variable "tags" {
  type    = map(string)
  default = {}
}