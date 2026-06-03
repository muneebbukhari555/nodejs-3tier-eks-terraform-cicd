terraform {
  required_version = ">= 1.11.0"
  required_providers {
    aws = { source = "hashicorp/aws", version = "~> 6.0" }
  }
}

# terraform {
#   backend "s3" {
#     bucket       = "node3tier-tf-state-<ACCOUNT_ID>"
#     key          = "bootstrap/terraform.tfstate"
#     region       = "us-east-2"
#     encrypt      = true
#     use_lockfile = true
#   }
# }
