output "db_instance_arn" {
  value = aws_db_instance.this.arn
}
output "db_instance_id" {
  value = aws_db_instance.this.id
}
output "db_endpoint" {
  value = aws_db_instance.this.address
}
output "secret_name" {
  value = aws_secretsmanager_secret.db.name
}
output "secret_arn" {
  value = aws_secretsmanager_secret.db.arn
}
