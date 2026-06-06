output "secret_names" {
  description = "Map of key → Secrets Manager secret name."
  value       = { for k, v in aws_secretsmanager_secret.this : k => v.name }
}

output "secret_arns" {
  description = "Map of key → Secrets Manager secret ARN."
  value       = { for k, v in aws_secretsmanager_secret.this : k => v.arn }
}
