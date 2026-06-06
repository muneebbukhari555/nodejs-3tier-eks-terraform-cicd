resource "aws_iam_policy" "external_secrets" {
  name        = "${var.name}-external-secrets"
  description = "Allow ESO to read Secrets Manager and SSM Parameter Store entries"

  policy = jsonencode({
    Version = "2012-10-17"
    Statement = [
      {
        Sid    = "SecretsManagerRead"
        Effect = "Allow"
        Action = [
          "secretsmanager:GetSecretValue",
          "secretsmanager:DescribeSecret",
          "secretsmanager:ListSecretVersionIds",
        ]
        # Scope to the configured prefix; set secret_prefix = "" to allow all.
        Resource = var.secret_prefix == "" ? "*" : "arn:aws:secretsmanager:${var.region}:*:secret:${var.secret_prefix}*"
      },
      {
        Sid    = "SSMParameterRead"
        Effect = "Allow"
        Action = [
          "ssm:GetParameter",
          "ssm:GetParameters",
          "ssm:GetParametersByPath",
          "ssm:DescribeParameters",
        ]
        Resource = var.secret_prefix == "" ? "*" : "arn:aws:ssm:${var.region}:*:parameter/${var.secret_prefix}*"
      },
    ]
  })

  tags = var.tags
}

# IRSA role

module "external_secrets_irsa" {
  source  = "terraform-aws-modules/iam/aws//modules/iam-role-for-service-accounts-eks"
  version = "~> 5.39"

  role_name = "${var.name}-external-secrets"

  oidc_providers = {
    main = {
      provider_arn = var.oidc_provider_arn
      # ESO's controller service account is named "external-secrets"
      # in the namespace it is installed into.
      namespace_service_accounts = ["${var.namespace}:external-secrets"]
    }
  }

  role_policy_arns = {
    external_secrets = aws_iam_policy.external_secrets.arn
  }

  tags = var.tags
}

# Namespace

resource "kubernetes_namespace_v1" "external_secrets" {
  metadata {
    name   = var.namespace
    labels = { name = var.namespace }
  }
}

# Helm release

resource "helm_release" "external_secrets" {
  name       = "external-secrets"
  repository = "https://charts.external-secrets.io"
  chart      = "external-secrets"
  # Use the plain string — Helm provider v3 deprecated resource references here.
  namespace = var.namespace
  version   = var.chart_version

  set = [
    {
      name  = "serviceAccount.annotations.eks\\.amazonaws\\.com/role-arn"
      value = module.external_secrets_irsa.iam_role_arn
    },
    # Install CRDs as part of the chart (default true; explicit for clarity).
    { name = "installCRDs", value = "true" },
  ]

  depends_on = [kubernetes_namespace_v1.external_secrets]
}

#ClusterSecretStore 

resource "kubectl_manifest" "cluster_secret_store" {
  yaml_body = yamlencode({
    apiVersion = "external-secrets.io/v1beta1"
    kind       = "ClusterSecretStore"
    metadata = {
      name = var.cluster_secret_store_name
    }
    spec = {
      provider = {
        aws = {
          service = "SecretsManager"
          region  = var.region
          auth = {
            jwt = {
              serviceAccountRef = {
                name      = "external-secrets"
                namespace = var.namespace
              }
            }
          }
        }
      }
    }
  })

  # CRDs are installed by the Helm chart — must exist before this resource.
  depends_on = [helm_release.external_secrets]
}
