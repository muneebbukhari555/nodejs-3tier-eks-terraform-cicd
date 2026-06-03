resource "aws_vpc" "mgmt" {
  cidr_block           = var.vpc_cidr
  enable_dns_support   = true
  enable_dns_hostnames = true
  tags                 = merge(var.tags, { Name = "${var.name}-mgmt-vpc" })
}

resource "aws_internet_gateway" "mgmt" {
  vpc_id = aws_vpc.mgmt.id
  tags   = merge(var.tags, { Name = "${var.name}-mgmt-igw" })
}

resource "aws_subnet" "public" {
  vpc_id                  = aws_vpc.mgmt.id
  cidr_block              = cidrsubnet(var.vpc_cidr, 8, 0)
  availability_zone       = var.availability_zone
  map_public_ip_on_launch = true
  tags                    = merge(var.tags, { Name = "${var.name}-mgmt-public" })
}

resource "aws_route_table" "public" {
  vpc_id = aws_vpc.mgmt.id
  route {
    cidr_block = "0.0.0.0/0"
    gateway_id = aws_internet_gateway.mgmt.id
  }
  tags = merge(var.tags, { Name = "${var.name}-mgmt-rt" })
}

resource "aws_route_table_association" "public" {
  subnet_id      = aws_subnet.public.id
  route_table_id = aws_route_table.public.id
}

# Runners are PRIVATE (no public IP); egress to GitHub/ECR via a NAT gateway.
resource "aws_eip" "nat" {
  domain = "vpc"
  tags   = merge(var.tags, { Name = "${var.name}-mgmt-nat-eip" })
}

resource "aws_nat_gateway" "mgmt" {
  allocation_id = aws_eip.nat.id
  subnet_id     = aws_subnet.public.id
  tags          = merge(var.tags, { Name = "${var.name}-mgmt-nat" })
  depends_on    = [aws_internet_gateway.mgmt]
}

resource "aws_subnet" "private" {
  for_each          = { for i, az in var.azs : az => i }
  vpc_id            = aws_vpc.mgmt.id
  cidr_block        = cidrsubnet(var.vpc_cidr, 8, each.value + 10)
  availability_zone = each.key
  tags              = merge(var.tags, { Name = "${var.name}-mgmt-private-${each.key}" })
}

resource "aws_route_table" "private" {
  vpc_id = aws_vpc.mgmt.id
  route {
    cidr_block     = "0.0.0.0/0"
    nat_gateway_id = aws_nat_gateway.mgmt.id
  }
  tags = merge(var.tags, { Name = "${var.name}-mgmt-private-rt" })
}

resource "aws_route_table_association" "private" {
  for_each       = aws_subnet.private
  subnet_id      = each.value.id
  route_table_id = aws_route_table.private.id
}

# ---- Security group ----
resource "aws_security_group" "bastion" {
  name        = "${var.name}-bastion-sg"
  description = "Bastion host"
  vpc_id      = aws_vpc.mgmt.id

  dynamic "ingress" {
    for_each = var.allowed_ssh_cidr == "" ? [] : [var.allowed_ssh_cidr]
    content {
      description = "SSH (optional, restricted)"
      from_port   = 22
      to_port     = 22
      protocol    = "tcp"
      cidr_blocks = [ingress.value]
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.tags, { Name = "${var.name}-bastion-sg" })
}

# ---- IAM role for SSM Session Manager ----
resource "aws_iam_role" "bastion" {
  name = "${var.name}-bastion-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "ec2.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.bastion.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_instance_profile" "bastion" {
  name = "${var.name}-bastion-profile"
  role = aws_iam_role.bastion.name
}

# ---- AMI + instance ----
data "aws_ami" "al2" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["amzn2-ami-hvm-*-x86_64-gp2"]
  }
}

resource "aws_instance" "bastion" {
  ami                    = data.aws_ami.al2.id
  instance_type          = var.instance_type
  subnet_id              = aws_subnet.public.id
  vpc_security_group_ids = [aws_security_group.bastion.id]
  iam_instance_profile   = aws_iam_instance_profile.bastion.name
  key_name               = var.key_name != "" ? var.key_name : null

  metadata_options {
    http_tokens = "required" # IMDSv2 only
  }

  user_data = <<-EOF
    #!/bin/bash
    yum update -y
    # psql client + kubectl for admin tasks from the bastion
    amazon-linux-extras enable postgresql14
    yum install -y postgresql
    curl -sLO "https://dl.k8s.io/release/v1.29.0/bin/linux/amd64/kubectl"
    install -m 0755 kubectl /usr/local/bin/kubectl
  EOF

  tags = merge(var.tags, { Name = "${var.name}-bastion" })
}
