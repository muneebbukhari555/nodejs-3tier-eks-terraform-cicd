##################################################### Global Variables

# Input Variables
# AWS Region
variable "aws_region" {
  description = "Region in which AWS Resources to be created"
  type        = string
}
# Environment Variable
variable "environment" {
  description = "Environment Variable used as a prefix"
  type        = string
}
# Business Division Project Name
variable "project" {
  type    = string
  default = "node3tier"
}
# Define Local Values in Terraform
locals {
  owners      = var.project
  environment = var.environment
  name        = "${var.project}-${var.environment}"
  common_tags = {
    owners      = local.owners
    environment = local.environment
  }
}

##################################################### VPC Network Variables 
# VPC Name
variable "vpc_name" {
  description = "VPC Name"
  type        = string
}
# VPC CIDR Block
variable "vpc_cidr_block" {
  description = "VPC CIDR Block"
  type        = string
}
# VPC Public Subnets
variable "vpc_public_subnets" {
  description = "VPC Public Subnets"
  type        = list(string)
}
# VPC Private Subnets
variable "vpc_private_subnets" {
  description = "VPC Private Subnets"
  type        = list(string)
}
# VPC Database Subnets
variable "vpc_database_subnets" {
  description = "VPC Database Subnets"
  type        = list(string)
}
# VPC Create Database Subnet Group (True / False)
variable "vpc_create_database_subnet_group" {
  description = "VPC Create Database Subnet Group"
  type        = bool
}
# VPC Create Database Subnet Route Table (True or False)
variable "vpc_create_database_subnet_route_table" {
  description = "VPC Create Database Subnet Route Table"
  type        = bool
}
# VPC Enable NAT Gateway (True or False) 
variable "vpc_enable_nat_gateway" {
  description = "Enable NAT Gateways for Private Subnets Outbound Communication"
  type        = bool
}

##################################################### EKS Variables 
variable "cluster_version" {
  type    = string
  default = "1.29"
}
variable "node_instance_types" {
  type    = list(string)
  default = ["t3.medium"]
}
variable "node_min_size" {
  type        = number
  default     = 3
  description = "Min nodes — 3 so the managed node group keeps one per AZ (HA)."
}
variable "node_max_size" {
  type    = number
  default = 6
}
variable "node_desired_size" {
  type    = number
  default = 3
}
variable "node_ami_type" {
  type    = string
  default = "AL2023_x86_64_STANDARD"
}
variable "node_capacity_type" {
  type    = string
  default = "ON_DEMAND"
}
variable "node_disk_size" {
  type    = number
  default = 30
}
variable "node_kubernetes_version" {
  type        = string
  default     = null
  description = "Node kubelet version; null = cluster_version"
}
# Pin EKS-managed addon versions, e.g. { coredns = "v1.11.1-eksbuild.9" }.
# Unset names use the most-recent compatible version.
variable "addon_versions" {
  type    = map(string)
  default = {}
}

variable "cluster_admin_principal_arns" {
  type = list(string)
}
variable "api_allowed_cidrs" {
  type = list(string)
}

##################################################### EKS Namespaces Variables
# variable "app_namespaces" {
#   type = list(string)
# }
##################################################### ECR Repositories Variables
variable "ecr_repositories" {
  type        = list(string)
  description = "Repository short names (e.g. web, api)"
  default     = []
}
variable "ecr_keep_last" {
  type    = number
  default = 20
}


##################################################### VPC Peering Variables
variable "mgmt_vpc_id" {
  type        = string
  description = "Bootstrap output: management VPC id (for peering)"
}
variable "mgmt_vpc_cidr" {
  type        = string
  default     = "10.1.0.0/16"
  description = "Management VPC CIDR. Must not overlap vpc_cidr."
}
variable "mgmt_route_table_ids" {
  type        = list(string)
  description = "Bootstrap output: mgmt route tables (public+private) for peering"
}

##################################################### Addon-ons AWS LB Controller, Cluster Autoscaler, metrics-server. Variables
variable "lb_controller_chart_version" {
  type = string
}
variable "cluster_autoscaler_chart_version" {
  type = string
}
variable "metrics_server_chart_version" {
  type = string
}

##################################################### RDS Variables
variable "db_name" {
  type    = string
  default = "appdb"
}
variable "db_username" {
  type    = string
  default = "appuser"
}
variable "db_instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "db_engine_version" {
  type    = string
  default = "15"
}
variable "db_allocated_storage" {
  type    = number
  default = 20
}
variable "db_max_allocated_storage" {
  type        = number
  default     = 0
  description = "Autoscaling ceiling (GB); 0 = 3x allocated"
}
variable "db_storage_type" {
  type    = string
  default = "gp3"
}
variable "db_multi_az" {
  type    = bool
  default = true
}
variable "db_backup_retention_days" {
  type    = number
  default = 7
}
variable "db_performance_insights_enabled" {
  type    = bool
  default = true
}
variable "db_deletion_protection" {
  type    = bool
  default = false
}
variable "db_skip_final_snapshot" {
  type    = bool
  default = true
}