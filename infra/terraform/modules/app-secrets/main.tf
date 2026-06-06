resource "aws_secretsmanager_secret" "this" {
  for_each = var.secrets

  name                    = "${var.secret_prefix}${each.key}"
  description             = each.value.description
  recovery_window_in_days = var.recovery_window_days
  tags                    = var.tags
}
