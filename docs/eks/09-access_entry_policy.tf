locals {
  cluster_admin_principals = var.cluster_admin_principal_arns
}

resource "aws_eks_access_entry" "admins" {
  for_each = toset(local.cluster_admin_principals)

  cluster_name  = aws_eks_cluster.eks_cluster.name
  principal_arn = each.value
  type          = "STANDARD"
}

resource "aws_eks_access_policy_association" "admins" {
  for_each = toset(local.cluster_admin_principals)

  cluster_name  = aws_eks_cluster.eks_cluster.name
  principal_arn = each.value
  policy_arn    = "arn:aws:eks::aws:cluster-access-policy/AmazonEKSClusterAdminPolicy"

  access_scope {
    type = "cluster"
  }
}