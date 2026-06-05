project      = "node3tier"
region       = "us-east-2"
github_owner = "muneebbukhari555"
github_repo  = "nodejs-3tier-eks-terraform-cicd"

mgmt_vpc_cidr = "10.1.0.0/16"
mgmt_azs      = ["us-east-2a", "us-east-2b"]

infra_runner_type    = "t3.small"
infra_runner_min     = 1
infra_runner_max     = 3
infra_runner_desired = 1

app_runner_type    = "m7i-flex.large"
app_runner_min     = 1
app_runner_max     = 3
app_runner_desired = 1
# Runner container image with terraform/kubectl/helm/docker/aws bundled.
# This variable will be used in second stage of pipeline to run terraform commands in a container.
runner_image = "839792743202.dkr.ecr.us-east-2.amazonaws.com/node3tier/runner:latest"

# Scope this down to the services Terraform manages for real production.
infra_policy_arn = "arn:aws:iam::aws:policy/AdministratorAccess"
