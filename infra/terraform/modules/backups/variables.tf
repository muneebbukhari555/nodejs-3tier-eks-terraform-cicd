variable "name" { type = string }
variable "backup_resource_arns" {
  type        = list(string)
  description = "ARNs to back up (e.g. RDS instance ARN)"
}
variable "schedule_cron" {
  type        = string
  default     = "cron(30 3 * * ? *)" # daily 03:30 UTC
  description = "AWS Backup schedule expression"
}
variable "retention_days" {
  type    = number
  default = 30
}
variable "tags" {
  type    = map(string)
  default = {}
}
