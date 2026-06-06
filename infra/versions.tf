# Terraform Block
terraform {
  required_version = ">= 1.15.0"
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.47.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes",
      version = "~> 3.1.0"
    }
    helm = {
      source  = "hashicorp/helm",
      version = "~> 3.2.0"
    }
  }
  # backend "s3" {
  #   bucket       = "node3tier-tf-state-839792743202"
  #   key          = "prod/node3tier.tfstate"
  #   region       = "us-east-2"
  #   encrypt      = true
  #   use_lockfile = true
  # }
}