# Create AWS EKS Node Group - Private
resource "aws_eks_node_group" "eks_ng_private" {
  cluster_name    = aws_eks_cluster.eks_cluster.name
  node_group_name = "${var.cluster_name}-ng-private"
  node_role_arn   = aws_iam_role.eks_nodegroup_role.arn
  subnet_ids      = var.private_subnets
  version         = var.cluster_version #(Optional: Defaults to EKS Cluster Kubernetes version)    

  ami_type       = var.ng_ami_type
  capacity_type  = "ON_DEMAND"
  disk_size      = var.ng_disk_size
  instance_types = var.ng_instance_type

  scaling_config {
    desired_size = var.scaling_desired_size
    min_size     = var.scaling_min_size
    max_size     = var.scaling_max_size
  }
  
  # Desired max percentage of unavailable worker nodes during node group update.
  update_config {
    max_unavailable = 1
    #max_unavailable_percentage = 50    # ANY ONE TO USE
  }

  # Ensure that IAM Role permissions are created before and deleted after EKS Node Group handling.
  depends_on = [
    aws_iam_role_policy_attachment.eks-AmazonEKSWorkerNodePolicy,
    aws_iam_role_policy_attachment.eks-AmazonEKS_CNI_Policy,
    aws_iam_role_policy_attachment.eks-AmazonEC2ContainerRegistryReadOnly,
  ]
  tags = {
    Name = "Private-Node-Group"
  }
}
