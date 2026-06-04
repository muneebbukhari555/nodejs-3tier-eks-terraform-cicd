resource "random_password" "db" {
  length  = 20
  special = false
}

resource "aws_security_group" "db" {
  name        = "${var.name}-db-sg"
  description = "Allow Postgres only from EKS nodes"
  vpc_id      = var.vpc_id

  ingress {
    description     = "Postgres from EKS nodes"
    from_port       = 5432
    to_port         = 5432
    protocol        = "tcp"
    security_groups = [var.node_security_group_id]
  }

  # Admin access from the bastion / management VPC (over VPC peering).
  dynamic "ingress" {
    for_each = length(var.admin_ingress_cidrs) > 0 ? [1] : []
    content {
      description = "Postgres from management VPC (bastion)"
      from_port   = 5432
      to_port     = 5432
      protocol    = "tcp"
      cidr_blocks = var.admin_ingress_cidrs
    }
  }

  egress {
    from_port   = 0
    to_port     = 0
    protocol    = "-1"
    cidr_blocks = ["0.0.0.0/0"]
  }
  tags = var.tags
}

resource "aws_db_instance" "this" {
  identifier     = "${var.name}-pg"
  engine         = "postgres"
  engine_version = var.engine_version
  instance_class = var.instance_class

  allocated_storage     = var.allocated_storage
  max_allocated_storage = var.max_allocated_storage > 0 ? var.max_allocated_storage : var.allocated_storage * 3
  storage_type          = var.storage_type
  storage_encrypted     = true

  db_name  = var.db_name
  username = var.db_username
  password = random_password.db.result
  port     = 5432

  multi_az               = var.multi_az
  db_subnet_group_name   = var.db_subnet_group_name
  vpc_security_group_ids = [aws_security_group.db.id]
  publicly_accessible    = false

  # Daily automated backups (point-in-time recovery)
  backup_retention_period   = var.backup_retention_days # >=1 enables daily backups
  backup_window             = var.backup_window
  maintenance_window        = var.maintenance_window
  copy_tags_to_snapshot     = true
  delete_automated_backups  = false
  deletion_protection       = var.deletion_protection
  skip_final_snapshot       = var.skip_final_snapshot
  final_snapshot_identifier = var.skip_final_snapshot ? null : "${var.name}-pg-final"
  apply_immediately         = true

  performance_insights_enabled          = var.performance_insights_enabled
  performance_insights_retention_period = var.performance_insights_enabled ? var.performance_insights_retention_period : null
  enabled_cloudwatch_logs_exports       = ["postgresql", "upgrade"]

  tags = var.tags
}

resource "aws_secretsmanager_secret" "db" {
  name = "${var.name}/db-credentials"
  tags = var.tags
}

resource "aws_secretsmanager_secret_version" "db" {
  secret_id = aws_secretsmanager_secret.db.id
  secret_string = jsonencode({
    DB     = var.db_name
    DBUSER = var.db_username
    DBPASS = random_password.db.result
    DBHOST = aws_db_instance.this.address
    DBPORT = tostring(aws_db_instance.this.port)
  })
}
