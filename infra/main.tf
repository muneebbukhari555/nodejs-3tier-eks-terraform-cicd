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

# In-cluster add-ons (Helm): AWS LB Controller, Cluster Autoscaler, metrics-server.
module "addons" {
  source                           = "./terraform/modules/addons"
  name                             = local.name
  region                           = var.aws_region
  cluster_name                     = module.eks.cluster_name
  vpc_id                           = module.network.vpc_id
  oidc_provider_arn                = module.eks.oidc_provider_arn
  lb_controller_chart_version      = var.lb_controller_chart_version
  cluster_autoscaler_chart_version = var.cluster_autoscaler_chart_version
  metrics_server_chart_version     = var.metrics_server_chart_version
  tags                             = local.common_tags
}

# Application namespace (web/api Helm charts deploy here).
resource "kubernetes_namespace" "app_namespace" {
  for_each = toset(var.app_namespaces)
  metadata {
    name   = each.value
    labels = { name = each.value }
  }
}

# Observability: CloudWatch Container Insights, CloudWatch Logs, and RDS Enhanced Monitoring.
module "observability" {
  source            = "./terraform/modules/observability"
  name              = local.name
  region            = var.aws_region
  cluster_name      = module.eks.cluster_name
  oidc_provider_arn = module.eks.oidc_provider_arn
  db_instance_id    = module.rds.db_instance_id
  tags              = local.common_tags
}

# Observability: CloudWatch Container Insights, CloudWatch Logs, and RDS Enhanced Monitoring.
module "rds" {
  source                 = "./terraform/modules/rds"
  name                   = var.project
  vpc_id                 = module.network.vpc_id
  db_subnet_group_name   = module.network.database_subnet_group_name
  node_security_group_id = module.eks.node_security_group_id
  admin_ingress_cidrs    = [var.mgmt_vpc_cidr]
  instance_class         = var.db_instance_class
  engine_version         = var.db_engine_version
  allocated_storage      = var.db_allocated_storage
  max_allocated_storage  = var.db_max_allocated_storage
  storage_type           = var.db_storage_type
  multi_az               = var.db_multi_az
  db_name                = var.db_name
  db_username            = var.db_username
  backup_retention_days  = var.db_backup_retention_days

  performance_insights_enabled = var.db_performance_insights_enabled
  deletion_protection          = var.db_deletion_protection
  skip_final_snapshot          = var.db_skip_final_snapshot
  tags                         = local.common_tags
}
