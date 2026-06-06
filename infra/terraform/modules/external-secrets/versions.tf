terraform {
  required_providers {
    aws = {
      source  = "hashicorp/aws"
      version = "~> 6.47.0"
    }
    kubernetes = {
      source  = "hashicorp/kubernetes",
      version = "~> 3.1.0"
    }
    helm = {
      source  = "hashicorp/helm",
      version = "~> 3.2.0"
    }
    # alekc/kubectl defers CRD validation to apply time (actively maintained
    # fork of the archived gavinbunney/kubectl; Terraform 1.x compatible).
    # Required for ClusterSecretStore, whose CRD is installed by the Helm chart
    # in the same apply kubernetes_manifest would fail at plan time.
    kubectl = {
      source  = "alekc/kubectl"
      version = "~> 2.0"
    }
  }
}
