output "role_arn" {
  value = aws_iam_role.runner.arn
}
output "role_name" {
  value = aws_iam_role.runner.name
}
output "asg_name" {
  value = aws_autoscaling_group.runner.name
}
output "security_group_id" {
  value = aws_security_group.runner.id
}
