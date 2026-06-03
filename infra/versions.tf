# Terraform Block
terraform {
  required_version = ">= 1.15.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.47.0"
    }
  }
  # backend "s3" {
  #   bucket       = "node3tier-tf-state-839792743202"
  #   key          = "prod/terraform.tfstate"
  #   region       = "us-east-2"
  #   use_lockfile = true
  #   encrypt      = true
  # }
}
# Provider Block
provider "aws" {
  region  = var.aws_region
  profile = "default"
}

