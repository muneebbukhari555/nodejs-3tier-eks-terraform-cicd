variable "name" {
  type        = string
  description = "Name prefix for all RDS resources (e.g. instance, subnet group, etc.)"
}
variable "vpc_id" {
  type        = string
  description = "VPC where RDS instance will be deployed"
}

variable "db_subnet_group_name" {
  type        = string
  description = "Name of the DB subnet group to use. Must be created separately and include at least 2 subnets in different AZs."
}
variable "node_security_group_id" {
  type        = string
  description = "Security group ID for EKS nodes"
}
variable "admin_ingress_cidrs" {
  type        = list(string)
  default     = []
  description = "Extra CIDRs allowed to reach Postgres (e.g. management/bastion VPC)"
}

variable "engine_version" {
  type    = string
  default = "15"
}
variable "instance_class" {
  type    = string
  default = "db.t3.micro"
}
variable "allocated_storage" {
  type    = number
  default = 20
}
variable "max_allocated_storage" {
  type        = number
  default     = 0
  description = "Storage autoscaling ceiling (GB). 0 = 3x allocated_storage."
}
variable "storage_type" {
  type    = string
  default = "gp3"
}
variable "multi_az" {
  type    = bool
  default = true
}
variable "performance_insights_enabled" {
  type    = bool
  default = true
}
variable "performance_insights_retention_period" {
  type    = number
  default = 7
}
variable "backup_window" {
  type    = string
  default = "03:00-04:00"
}
variable "maintenance_window" {
  type    = string
  default = "Mon:04:00-Mon:05:00"
}
variable "db_name" {
  type    = string
  default = "appdb"
}
variable "db_username" {
  type    = string
  default = "appuser"
}
variable "backup_retention_days" {
  type    = number
  default = 7
}
variable "deletion_protection" {
  type    = bool
  default = false
}
variable "skip_final_snapshot" {
  type    = bool
  default = true
}
variable "tags" {
  type    = map(string)
  default = {}
}
