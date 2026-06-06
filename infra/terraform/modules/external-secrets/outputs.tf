output "irsa_role_arn" {
  description = "IAM role ARN annotated on the ESO service account."
  value       = module.external_secrets_irsa.iam_role_arn
}

output "cluster_secret_store_name" {
  description = "Name of the ClusterSecretStore created in-cluster."
  value       = var.cluster_secret_store_name
}

output "namespace" {
  description = "Kubernetes namespace the operator is installed into."
  value       = kubernetes_namespace.external_secrets.metadata[0].name
}
