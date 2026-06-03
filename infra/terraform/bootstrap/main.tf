provider "aws" {
  region = var.region
  default_tags { tags = var.tags }
}

data "aws_caller_identity" "current" {}

locals {
  account_id   = data.aws_caller_identity.current.account_id
  state_bucket = "${var.project}-tf-state-${local.account_id}"
  github_url   = "https://github.com/${var.github_owner}/${var.github_repo}"
}

# Remote state backend: S3 (versioned, encrypted, private). Native locking.

resource "aws_s3_bucket" "state" {
  bucket = local.state_bucket
}
resource "aws_s3_bucket_versioning" "state" {
  bucket = aws_s3_bucket.state.id
  versioning_configuration { status = "Enabled" }
}
resource "aws_s3_bucket_server_side_encryption_configuration" "state" {
  bucket = aws_s3_bucket.state.id
  rule {
    apply_server_side_encryption_by_default { sse_algorithm = "AES256" }
  }
}
resource "aws_s3_bucket_public_access_block" "state" {
  bucket                  = aws_s3_bucket.state.id
  block_public_acls       = true
  block_public_policy     = true
  ignore_public_acls      = true
  restrict_public_buckets = true
}

# ECR repo for the CUSTOM RUNNER IMAGE (built by runner-image.yml). Created in
resource "aws_ecr_repository" "runner" {
  name                 = "${var.project}/runner"
  image_tag_mutability = "MUTABLE"
  image_scanning_configuration { scan_on_push = true }
  encryption_configuration { encryption_type = "AES256" }
  tags = var.tags
}

# Management VPC + bastion + private subnets/NAT (for the runner fleets)

module "bastion" {
  source            = "../modules/bastion"
  name              = var.project
  vpc_cidr          = var.mgmt_vpc_cidr
  availability_zone = var.mgmt_azs[0]
  azs               = var.mgmt_azs
  allowed_ssh_cidr  = ""
  tags              = var.tags
}

# Runner registration token (set the value out-of-band after apply):
resource "aws_ssm_parameter" "runner_token" {
  name  = var.runner_token_ssm_param
  type  = "SecureString"
  value = "REPLACE_ME"
  lifecycle { ignore_changes = [value] }
  tags = var.tags
}

# INFRA runner fleet — runs Terraform. Broad deploy perms (scope down for
data "aws_iam_policy_document" "infra_state" {
  statement {
    sid       = "StateBucket"
    effect    = "Allow"
    actions   = ["s3:ListBucket"]
    resources = [aws_s3_bucket.state.arn]
  }
  statement {
    sid       = "StateObjects"
    effect    = "Allow"
    actions   = ["s3:GetObject", "s3:PutObject", "s3:DeleteObject"]
    resources = ["${aws_s3_bucket.state.arn}/*"]
  }
}

module "runner_infra" {
  source                 = "../modules/runner-fleet"
  name                   = "${var.project}-infra"
  region                 = var.region
  vpc_id                 = module.bastion.vpc_id
  subnet_ids             = module.bastion.private_subnet_ids
  github_url             = local.github_url
  runner_token_ssm_param = var.runner_token_ssm_param
  runner_labels          = "self-hosted,linux,infra"
  runner_image           = var.runner_image
  managed_policy_arns    = [var.infra_policy_arn]
  inline_policy_json     = data.aws_iam_policy_document.infra_state.json
  create_inline_policy   = true
  instance_type          = var.infra_runner_type
  min_size               = var.infra_runner_min
  max_size               = var.infra_runner_max
  desired_capacity       = var.infra_runner_desired
  tags                   = var.tags
}

# APP runner fleet — build/scan/push + helm deploy. Least privilege:
data "aws_iam_policy_document" "app_perms" {
  statement {
    sid       = "ECRAuth"
    effect    = "Allow"
    actions   = ["ecr:GetAuthorizationToken"]
    resources = ["*"]
  }
  statement {
    sid    = "ECRPushPull"
    effect = "Allow"
    actions = [
      "ecr:BatchCheckLayerAvailability",
      "ecr:GetDownloadUrlForLayer",
      "ecr:BatchGetImage",
      "ecr:PutImage",
      "ecr:InitiateLayerUpload",
      "ecr:UploadLayerPart",
      "ecr:CompleteLayerUpload",
    ]
    resources = ["arn:aws:ecr:${var.region}:${local.account_id}:repository/${var.project}/*"]
  }
  statement {
    sid       = "EKSDescribe"
    effect    = "Allow"
    actions   = ["eks:DescribeCluster"]
    resources = ["arn:aws:eks:${var.region}:${local.account_id}:cluster/${var.project}-eks"]
  }
}

module "runner_app" {
  source                 = "../modules/runner-fleet"
  name                   = "${var.project}-app"
  region                 = var.region
  vpc_id                 = module.bastion.vpc_id
  subnet_ids             = module.bastion.private_subnet_ids
  github_url             = local.github_url
  runner_token_ssm_param = var.runner_token_ssm_param
  runner_labels          = "self-hosted,linux,app"
  runner_image           = var.runner_image
  inline_policy_json     = data.aws_iam_policy_document.app_perms.json
  create_inline_policy   = true
  instance_type          = var.app_runner_type
  min_size               = var.app_runner_min
  max_size               = var.app_runner_max
  desired_capacity       = var.app_runner_desired
  tags                   = var.tags
}
