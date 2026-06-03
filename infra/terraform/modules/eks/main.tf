module "eks" {
  source  = "terraform-aws-modules/eks/aws"
  version = "~> 21.0"

  name               = "${var.name}-eks"
  kubernetes_version = var.cluster_version

  endpoint_private_access      = var.endpoint_private_access

  enable_cluster_creator_admin_permissions = false
  security_group_additional_rules = length(var.api_allowed_cidrs) > 0 ? {
    ingress_api_admin = {
      description = "EKS API from admin/runner CIDRs"
      type        = "ingress"
      protocol    = "tcp"
      from_port   = 443
      to_port     = 443
      cidr_blocks = var.api_allowed_cidrs
    }
  } : {}

  # Grant cluster-admin to the bastion and runner IAM roles via access entries.
  access_entries = {
    for i, arn in var.cluster_admin_principal_arns : "admin-${i}" => {
      principal_arn = arn
      policy_associations = {
        admin = {
          policy_arn   = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"
          access_scope = { type = "cluster" }
        }
      }
    }
  }
  vpc_id     = var.vpc_id
  subnet_ids = var.private_subnets

  addons = {
    vpc-cni = {
      before_compute = true
      addon_version = lookup(var.addon_versions, "vpc-cni", null)
      most_recent   = lookup(var.addon_versions, "vpc-cni", null) == null
    }

    kube-proxy = {
      before_compute = true
      addon_version = lookup(var.addon_versions, "kube-proxy", null)
      most_recent   = lookup(var.addon_versions, "kube-proxy", null) == null
    }

    coredns = {
      addon_version = lookup(var.addon_versions, "coredns", null)
      most_recent   = lookup(var.addon_versions, "coredns", null) == null
    }
  }
  
  eks_managed_node_groups = {
    default = {
      ami_type           = var.node_ami_type
      capacity_type      = var.node_capacity_type
      disk_size          = var.node_disk_size
      instance_types     = var.node_instance_types
      min_size           = var.node_min_size
      max_size           = var.node_max_size
      desired_size       = var.node_desired_size
      kubernetes_version = var.node_kubernetes_version

      # Let the node role use SSM Session Manager so you can shell into nodes to
      # debug bootstrap (TargetNotConnected = no egress to SSM/ECR/EKS).
      iam_role_additional_policies = {
        ssm = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
      }

      labels = { role = "app" }
      tags = {
        "k8s.io/cluster-autoscaler/enabled"         = "true"
        "k8s.io/cluster-autoscaler/${var.name}-eks" = "owned"
      }
    }
  }
  enabled_log_types = ["api", "audit", "authenticator", "controllerManager", "scheduler"]

  tags = var.tags
}
