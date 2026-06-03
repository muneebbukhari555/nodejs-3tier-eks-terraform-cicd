project      = "node3tier"
region       = "us-east-2"
github_owner = "muneebbukhari555"
github_repo  = "nodejs-3tier-eks-terraform-cicd"

mgmt_vpc_cidr = "10.1.0.0/16"
mgmt_azs      = ["us-east-2a", "us-east-2b"]

# Runner container image with terraform/kubectl/helm/docker/aws bundled.
runner_image = "839792743202.dkr.ecr.us-east-2.amazonaws.com/node3tier/runner:latest"

# Scope this down to the services Terraform manages for real production.
infra_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
