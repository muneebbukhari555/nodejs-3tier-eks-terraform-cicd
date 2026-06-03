# Generic Variables
aws_region  = "us-east-2"
environment = "prod"

# VPC Variables
vpc_name                               = "eks-vpc"
vpc_cidr_block                         = "10.0.0.0/16"
vpc_public_subnets                     = ["10.0.101.0/24", "10.0.102.0/24", "10.0.103.0/24"]
vpc_private_subnets                    = ["10.0.1.0/24", "10.0.2.0/24", "10.0.3.0/24"]
vpc_database_subnets                   = ["10.0.151.0/24", "10.0.152.0/24", "10.0.153.0/24"]
vpc_create_database_subnet_group       = true
vpc_create_database_subnet_route_table = true
vpc_enable_nat_gateway                 = true

# EKS Cluster Variables
cluster_version     = "1.35"
node_instance_types = ["m7i-flex.large"]
node_min_size       = 1
node_max_size       = 6
node_desired_size   = 1
node_ami_type       = "AL2023_x86_64_STANDARD"
node_capacity_type  = "ON_DEMAND"
node_disk_size      = 30
eks_public_access   = false
api_allowed_cidrs   = ["10.1.0.0/16", "10.0.0.0/16"]
addon_versions = {
  vpc-cni            = "v1.21.1-eksbuild.1"
  kube-proxy         = "v1.35.3-eksbuild.2"
  coredns            = "v1.13.2-eksbuild.4"
  aws-ebs-csi-driver = "v1.60.1-eksbuild.1"
}
cluster_admin_principal_arns = [
  "arn:aws:iam::839792743202:user/toptal",
  "arn:aws:iam::839792743202:role/node3tier-app-runner-role",
  "arn:aws:iam::839792743202:role/node3tier-bastion-role",
  "arn:aws:iam::839792743202:role/node3tier-infra-runner-role"
]

# ECR Repositories to Create
ecr_repositories = [
  "web",
  "api"
]
ecr_keep_last = 30