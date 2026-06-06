##################################################### Generic Variables
aws_region  = "us-east-2"
environment = "prod"

##################################################### VPC Peering Variables
mgmt_vpc_id          = "vpc-0d97d86e08ed5dcfa"
mgmt_vpc_cidr        = "10.1.0.0/16"
mgmt_route_table_ids = ["rtb-0c24cc7d6b635c5e3", "rtb-08af318b25eff723f"]

# VPC Variables
vpc_name                               = "eks-vpc"
vpc_cidr_block                         = "10.0.0.0/16"
vpc_public_subnets                     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
vpc_private_subnets                    = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
vpc_database_subnets                   = ["10.0.151.0/24", "10.0.152.0/24", "10.0.153.0/24"]
vpc_create_database_subnet_group       = true
vpc_create_database_subnet_route_table = true
vpc_enable_nat_gateway                 = true

##################################################### EKS Cluster Variables
enable_k8s_resources = false # set true to create in-cluster add-ons and namespaces. Set false to skip (for faster iteration when only infra changes).
cluster_version      = "1.35"
node_instance_types  = ["m7i-flex.large"]
node_min_size        = 1
node_max_size        = 6
node_desired_size    = 1
node_ami_type        = "AL2023_x86_64_STANDARD"
node_capacity_type   = "ON_DEMAND"
node_disk_size       = 30
api_allowed_cidrs    = ["10.1.0.0/16", "10.0.0.0/16"]
addon_versions = {
  vpc-cni            = "v1.21.1-eksbuild.1"
  kube-proxy         = "v1.35.3-eksbuild.2"
  coredns            = "v1.13.2-eksbuild.4"
  aws-ebs-csi-driver = "v1.60.1-eksbuild.1"
}
cluster_admin_principal_arns = [
  "arn:aws:iam::839792743202:user/toptal",
  "arn:aws:iam::839792743202:role/node3tier-prod-app-runner-role",
  "arn:aws:iam::839792743202:role/node3tier-prod-bastion-role",
  "arn:aws:iam::839792743202:role/node3tier-prod-infra-runner-role"
]

##################################################### EKS Namespaces to Create
app_namespaces = [
  "app"
]

##################################################### ECR Repositories to Create
ecr_repositories = [
  "web",
  "api"
]
ecr_keep_last = 30

##################################################### External Secrets Variables
external_secrets_chart_version = "2.4.0"
secrets_prefix                 = "node3tier-prod"

##################################################### Addon-ons AWS LB Controller, Cluster Autoscaler, metrics-server. Variables
lb_controller_chart_version      = "3.3.0"
cluster_autoscaler_chart_version = "9.56.0"
metrics_server_chart_version     = "3.13.0"

##################################################### RDS Database Variables
db_name                         = "appdb"
db_username                     = "appuser"
db_instance_class               = "db.t3.micro"
db_engine_version               = "18.1"
db_allocated_storage            = 20
db_max_allocated_storage        = 0 # 0 = 3x allocated
db_storage_type                 = "gp3"
db_multi_az                     = true
db_backup_retention_days        = 1
db_performance_insights_enabled = true
db_deletion_protection          = false # set true for real prod
db_skip_final_snapshot          = true  # set false for real prod

##################################################### ACM AND CDN Variables
domain_name      = "tryweblytic.com"
route53_zone_id  = "Z02362342ZQ56SR8N24GK"
web_alb_dns_name = "node3tier-prod-ingress-1724904820.us-east-2.elb.amazonaws.com"