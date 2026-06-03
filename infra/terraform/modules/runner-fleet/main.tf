
# Self-hosted GitHub Actions runner FLEET — ephemeral, container-based, ASG.

resource "aws_security_group" "runner" {
  name        = "${var.name}-runner-sg"
  description = "Self-hosted runner fleet (egress only)"
  vpc_id      = var.vpc_id
  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = merge(var.tags, { Name = "${var.name}-runner-sg" })
}

# ---- IAM role (instance identity) ----
resource "aws_iam_role" "runner" {
  name = "${var.name}-runner-role"
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

# Always-on: SSM management + read the registration token from SSM.
resource "aws_iam_role_policy_attachment" "ssm" {
  role       = aws_iam_role.runner.name
  policy_arn = "arn:aws:iam::aws:policy/AmazonSSMManagedInstanceCore"
}

resource "aws_iam_role_policy" "token" {
  name = "read-runner-token"
  role = aws_iam_role.runner.id
  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Effect   = "Allow"
      Action   = ["ssm:GetParameter"]
      Resource = "arn:aws:ssm:${var.region}:*:parameter${var.runner_token_ssm_param}"
    }]
  })
}

# Fleet-specific managed policies (e.g. infra deploy, ECR).
resource "aws_iam_role_policy_attachment" "extra" {
  for_each   = toset(var.managed_policy_arns)
  role       = aws_iam_role.runner.name
  policy_arn = each.value
}

# Optional fleet-specific inline policy.
resource "aws_iam_role_policy" "inline" {
  count  = var.create_inline_policy ? 1 : 0
  name   = "${var.name}-inline"
  role   = aws_iam_role.runner.id
  policy = var.inline_policy_json
}

resource "aws_iam_instance_profile" "runner" {
  name = "${var.name}-runner-profile"
  role = aws_iam_role.runner.name
}

data "aws_ami" "al2023" {
  most_recent = true
  owners      = ["amazon"]
  filter {
    name   = "name"
    values = ["al2023-ami-*-x86_64"]
  }
}

locals {
  user_data = base64encode(templatefile("${path.module}/userdata.sh.tftpl", {
    github_url    = var.github_url
    runner_labels = var.runner_labels
    runner_image  = var.runner_image
    token_param   = var.runner_token_ssm_param
    region        = var.region
  }))
}

resource "aws_launch_template" "runner" {
  name_prefix            = "${var.name}-runner-"
  image_id               = data.aws_ami.al2023.id
  instance_type          = var.instance_type
  vpc_security_group_ids = [aws_security_group.runner.id]
  user_data              = local.user_data

  iam_instance_profile {
    name = aws_iam_instance_profile.runner.name
  }
  metadata_options {
    http_tokens   = "required" # IMDSv2 only
    http_endpoint = "enabled"
  }
  tag_specifications {
    resource_type = "instance"
    tags          = merge(var.tags, { Name = "${var.name}-runner" })
  }
}

resource "aws_autoscaling_group" "runner" {
  name                = "${var.name}-runners"
  min_size            = var.min_size
  max_size            = var.max_size
  desired_capacity    = var.desired_capacity
  vpc_zone_identifier = var.subnet_ids

  launch_template {
    id      = aws_launch_template.runner.id
    version = "$Latest"
  }
  # Ephemeral: instances are replaced (fresh per job) rather than reused.
  instance_refresh {
    strategy = "Rolling"
  }
  tag {
    key                 = "Name"
    value               = "${var.name}-runner"
    propagate_at_launch = true
  }
}
