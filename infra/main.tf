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

module "eks" {
  source                  = "./terraform/modules/eks"
  name                    = var.project
  cluster_version         = var.cluster_version
  vpc_id                  = module.network.vpc_id
  private_subnets         = module.network.private_subnets
  node_instance_types     = var.node_instance_types
  node_min_size           = var.node_min_size
  node_max_size           = var.node_max_size
  node_desired_size       = var.node_desired_size
  node_ami_type           = var.node_ami_type
  node_capacity_type      = var.node_capacity_type
  node_disk_size          = var.node_disk_size
  addon_versions          = var.eks_addon_versions
  api_allowed_cidrs       = [var.mgmt_vpc_cidr, module.network.vpc_cidr_block]
  cluster_admin_principal_arns = [
    var.bastion_role_arn,
    var.infra_runner_role_arn,
    var.app_runner_role_arn,
  ]

  tags = local.common_tags
}

module "ecr" {
  source = "./terraform/modules/ecr"
  name         = var.project
  repositories = var.ecr_repositories
  keep_last    = var.ecr_keep_last
  tags         = local.common_tags
}