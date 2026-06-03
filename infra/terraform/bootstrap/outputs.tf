output "state_bucket" {
  value       = aws_s3_bucket.state.id
  description = "Put this in infra/backend.tf `bucket`"
}

output "runner_repo_url" {
  value       = aws_ecr_repository.runner.repository_url
  description = "Build/push the custom runner image here; set runner_image to <url>:<tag>"
}

# ---- Management VPC (consumed by the infra root for peering + API access) ----
output "mgmt_vpc_id" {
  value = module.bastion.vpc_id
}
output "mgmt_vpc_cidr" {
  value = module.bastion.vpc_cidr
}
output "mgmt_route_table_ids" {
  value = module.bastion.route_table_ids
}
output "bastion_instance_id" {
  description = "aws ssm start-session --target <id>"
  value       = module.bastion.instance_id
}
output "bastion_role_arn" {
  value = module.bastion.role_arn
}

# ---- Runner fleet role ARNs (granted EKS access in the infra root) ----
output "infra_runner_role_arn" {
  value = module.runner_infra.role_arn
}
output "app_runner_role_arn" {
  value = module.runner_app.role_arn
}
