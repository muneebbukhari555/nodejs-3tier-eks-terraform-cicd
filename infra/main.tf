module "vpc" {
  source                                 = "./modules/vpc"
  vpc_name                               = "${local.name}-${var.vpc_name}"
  vpc_cidr_block                         = var.vpc_cidr_block
  vpc_public_subnets                     = var.vpc_public_subnets
  vpc_private_subnets                    = var.vpc_private_subnets
  vpc_database_subnets                   = var.vpc_database_subnets
  vpc_create_database_subnet_group       = var.vpc_create_database_subnet_group
  vpc_create_database_subnet_route_table = var.vpc_create_database_subnet_route_table
  vpc_enable_nat_gateway                 = var.vpc_enable_nat_gateway
  common_tags                            = local.common_tags
  eks_cluster_name                       = "eks-cluster-name"
}