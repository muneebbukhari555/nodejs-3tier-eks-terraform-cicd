output "repository_urls" {
  description = "Map of short name -> repository URL"
  value       = { for k, r in aws_ecr_repository.ecr : k => r.repository_url }
}

output "repository_arns" {
  description = "List of repository ARNs (for IRSA push policy)"
  value       = [for r in aws_ecr_repository.ecr : r.arn]
}
