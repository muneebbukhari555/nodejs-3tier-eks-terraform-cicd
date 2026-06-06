# Daily backups via AWS Backup (in addition to RDS automated backups).

resource "aws_backup_vault" "this" {
  name = "${var.name}-vault"
  tags = var.tags
}

resource "aws_backup_plan" "daily" {
  name = "${var.name}-daily"

  rule {
    rule_name         = "daily-backup"
    target_vault_name = aws_backup_vault.this.name
    schedule          = var.schedule_cron # daily
    start_window      = 60
    completion_window = 180

    lifecycle {
      delete_after = var.retention_days
    }
  }
  tags = var.tags
}

resource "aws_iam_role" "backup" {
  name = "${var.name}-backup-role"
  assume_role_policy = jsonencode({
    Version = "2012-10-17"
    Statement = [{
      Action    = "sts:AssumeRole"
      Effect    = "Allow"
      Principal = { Service = "backup.amazonaws.com" }
    }]
  })
  tags = var.tags
}

resource "aws_iam_role_policy_attachment" "backup" {
  role       = aws_iam_role.backup.name
  policy_arn = "arn:aws:iam::aws:policy/service-role/AWSBackupServiceRolePolicyForBackup"
}

resource "aws_backup_selection" "resources" {
  iam_role_arn = aws_iam_role.backup.arn
  name         = "${var.name}-selection"
  plan_id      = aws_backup_plan.daily.id
  resources    = var.backup_resource_arns
}
