/*
# Security Group for EKS Node Group - Placeholder file
resource "aws_security_group" "eks_node_group" {
  name = "${var.cluster_name}-sg-eksnode"
  vpc_id = var.vpc_id

  # Allow outbound traffic to the control plane
  egress {
    from_port   = 443
    to_port     = 443
    protocol    = "tcp"
    cidr_blocks = ["0.0.0.0/0"]
  }

  # Allow inbound traffic from the control plane
  ingress {
    from_port   = 1025
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  # Allow inbound traffic for node-to-node communication
  ingress {
    from_port   = 0
    to_port     = 65535
    protocol    = "tcp"
    cidr_blocks = [var.vpc_cidr_block]
  }

  tags = var.common_tags
}
*/
