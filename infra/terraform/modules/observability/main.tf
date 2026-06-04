# Centralized logs + metrics via the CloudWatch Observability add-on, plus a
# dashboard and an example RDS alarm.

module "cw_observability_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name = "${var.name}-cw-observability"
  role_policy_arns = {
    cw = "arn:aws:iam::aws:policy/CloudWatchAgentServerPolicy"
  }
  oidc_providers = {
    main = {
      provider_arn               = var.oidc_provider_arn
      namespace_service_accounts = ["amazon-cloudwatch:cloudwatch-agent"]
    }
  }
  tags = var.tags
}

resource "aws_eks_addon" "cloudwatch_observability" {
  cluster_name                = var.cluster_name
  addon_name                  = "amazon-cloudwatch-observability"
  service_account_role_arn    = module.cw_observability_irsa.iam_role_arn
  resolve_conflicts_on_create = "OVERWRITE"
  resolve_conflicts_on_update = "OVERWRITE"
}

resource "aws_cloudwatch_dashboard" "main" {
  dashboard_name = "${var.name}-overview"
  dashboard_body = jsonencode({
    widgets = [
      {
        type = "metric", x = 0, y = 0, width = 12, height = 6
        properties = {
          title  = "EKS Node CPU / Memory"
          region = var.region
          period = 60
          stat   = "Average"
          metrics = [
            ["ContainerInsights", "node_cpu_utilization", "ClusterName", var.cluster_name],
            ["ContainerInsights", "node_memory_utilization", "ClusterName", var.cluster_name]
          ]
        }
      },
      {
        type = "metric", x = 12, y = 0, width = 12, height = 6
        properties = {
          title   = "Running Pods (app ns)"
          region  = var.region
          period  = 60
          stat    = "Average"
          metrics = [["ContainerInsights", "namespace_number_of_running_pods", "ClusterName", var.cluster_name, "Namespace", "app"]]
        }
      },
      {
        type = "metric", x = 0, y = 6, width = 12, height = 6
        properties = {
          title  = "RDS CPU & Connections"
          region = var.region
          period = 60
          stat   = "Average"
          metrics = [
            ["AWS/RDS", "CPUUtilization", "DBInstanceIdentifier", var.db_instance_id],
            ["AWS/RDS", "DatabaseConnections", "DBInstanceIdentifier", var.db_instance_id]
          ]
        }
      },
      {
        type = "metric", x = 12, y = 6, width = 12, height = 6
        properties = {
          title  = "ALB Requests & 5XX"
          region = var.region
          period = 60
          stat   = "Sum"
          metrics = [
            ["AWS/ApplicationELB", "RequestCount"],
            ["AWS/ApplicationELB", "HTTPCode_Target_5XX_Count"]
          ]
        }
      }
    ]
  })
}

resource "aws_cloudwatch_metric_alarm" "rds_cpu_high" {
  alarm_name          = "${var.name}-rds-cpu-high"
  comparison_operator = "GreaterThanThreshold"
  evaluation_periods  = 3
  metric_name         = "CPUUtilization"
  namespace           = "AWS/RDS"
  period              = 60
  statistic           = "Average"
  threshold           = 80
  dimensions          = { DBInstanceIdentifier = var.db_instance_id }
  tags                = var.tags
}
