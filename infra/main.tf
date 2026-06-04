# Workload VPC and Subnets
module "network" {
  source                                 = "./terraform/modules/network"
  name                                   = local.name
  vpc_cidr_block                         = var.vpc_cidr_block
  vpc_public_subnets                     = var.vpc_public_subnets
  vpc_private_subnets                    = var.vpc_private_subnets
  vpc_database_subnets                   = var.vpc_database_subnets
  vpc_create_database_subnet_group       = var.vpc_create_database_subnet_group
  vpc_create_database_subnet_route_table = var.vpc_create_database_subnet_route_table
  vpc_enable_nat_gateway                 = var.vpc_enable_nat_gateway
  common_tags                            = local.common_tags
  eks_cluster_name                       = "${local.name}-eks"
}

# EKS Cluster
module "eks" {
  source                       = "./terraform/modules/eks"
  name                         = local.name
  cluster_version              = var.cluster_version
  vpc_id                       = module.network.vpc_id
  private_subnets              = module.network.private_subnets
  node_instance_types          = var.node_instance_types
  node_min_size                = var.node_min_size
  node_max_size                = var.node_max_size
  node_desired_size            = var.node_desired_size
  node_ami_type                = var.node_ami_type
  node_capacity_type           = var.node_capacity_type
  node_disk_size               = var.node_disk_size
  addon_versions               = var.addon_versions
  api_allowed_cidrs            = var.api_allowed_cidrs
  cluster_admin_principal_arns = var.cluster_admin_principal_arns

  tags = local.common_tags
}

# ECR Repositories
module "ecr" {
  source       = "./terraform/modules/ecr"
  name         = local.name
  repositories = var.ecr_repositories
  keep_last    = var.ecr_keep_last
  tags         = local.common_tags
}

# VPC Peering
locals {
  workload_route_tables = {
    for idx, rt in module.network.route_table_ids :
    "rt-${idx}" => rt
  }
}
module "peering" {
  source                   = "./terraform/modules/peering"
  name                     = local.name
  mgmt_vpc_id              = var.mgmt_vpc_id
  mgmt_vpc_cidr            = var.mgmt_vpc_cidr
  mgmt_route_table_ids     = var.mgmt_route_table_ids
  workload_vpc_id          = module.network.vpc_id
  workload_vpc_cidr        = module.network.vpc_cidr_block
  workload_route_table_ids = local.workload_route_tables
  tags                     = local.common_tags
}