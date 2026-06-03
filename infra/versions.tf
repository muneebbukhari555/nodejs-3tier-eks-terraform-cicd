# Terraform Block
terraform {
  required_version = ">= 1.15.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.47.0"
    }
  }
  backend "s3" {}
}
# Provider Block
provider "aws" {
  region = var.aws_region
}

