output "vpc_id" {
  value = aws_vpc.mgmt.id
}
output "vpc_cidr" {
  value = aws_vpc.mgmt.cidr_block
}
output "route_table_id" {
  value = aws_route_table.public.id
}
output "route_table_ids" {
  description = "All mgmt route tables (public + private) for peering routes"
  value       = [aws_route_table.public.id, aws_route_table.private.id]
}
output "private_subnet_ids" {
  description = "Private mgmt subnets for the runner fleets"
  value       = [for s in aws_subnet.private : s.id]
}
output "security_group_id" {
  value = aws_security_group.bastion.id
}
output "instance_id" {
  value = aws_instance.bastion.id
}
output "role_arn" {
  value = aws_iam_role.bastion.arn
}
output "public_ip" {
  value = aws_instance.bastion.public_ip
}
