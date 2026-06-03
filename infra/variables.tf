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

variable "mgmt_vpc_cidr" {
  type        = string
  default     = "10.1.0.0/16"
  description = "Management VPC CIDR. Must not overlap vpc_cidr."
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
variable "eks_public_access" {
  type        = bool
  default     = false
  description = "Expose the EKS API publicly. Keep false for a private cluster."
}
# Pin EKS-managed addon versions, e.g. { coredns = "v1.11.1-eksbuild.9" }.
# Unset names use the most-recent compatible version.
variable "eks_addon_versions" {
  type    = map(string)
  default = {}
}

##################################################### Variables for EKS Cluster Admin Access
variable "bastion_role_arn" {
  type        = string
  description = "Bootstrap output: bastion instance role ARN"
}
variable "infra_runner_role_arn" {
  type        = string
  description = "Bootstrap output: infra runner fleet instance role ARN"
}
variable "app_runner_role_arn" {
  type        = string
  description = "Bootstrap output: app runner fleet instance role ARN"
}

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