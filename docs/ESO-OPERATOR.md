# External Secrets Operator — Deployment Guide

Deploys [external-secrets-operator](https://external-secrets.io) to the EKS cluster via the `external-secrets` Terraform module. The operator syncs AWS Secrets Manager (and SSM Parameter Store) entries into Kubernetes `Secret` objects without embedding static credentials.

---

## Architecture

```
AWS Secrets Manager
        │
        │  GetSecretValue (scoped by prefix)
        ▼
  IRSA IAM Role  ◄──── OIDC token (projected by EKS)
        │
        ▼
  ESO Controller Pod (external-secrets namespace)
        │
        │  reconciles ExternalSecret CRs
        ▼
  Kubernetes Secret  ◄── consumed by your app pods
```

The IAM role is scoped to secrets whose name starts with `node3tier/` (configurable via `external_secrets_prefix`). No static AWS credentials are used anywhere.

---

## Prerequisites

- Terraform ≥ 1.11
- EKS cluster applied (`module.eks` outputs available)
- `aws`, `helm`, and `kubernetes` providers configured (see `providers.tf`)
- AWS CLI + `kubectl` access to the cluster (via bastion or infra runner)

---

## Step 1 — Check/update the chart version

The module pins `chart_version` to a known-good release. Before deploying, verify the latest stable version:

```bash
helm repo add external-secrets https://charts.external-secrets.io
helm repo update
helm search repo external-secrets/external-secrets --versions | head -5
```

Update `modules/external-secrets/variables.tf` if a newer version is available:

```hcl
variable "chart_version" {
  default = "0.10.7"   # ← bump this
  ...
}
```

---

## Step 2 — (Optional) Scope the IAM prefix

By default the IRSA role allows access to secrets prefixed with `node3tier/`. To change the scope, set in `environments/prod/prod.tfvars`:

```hcl
external_secrets_prefix = "node3tier/"   # or "" to allow all (not recommended)
```

---

## Step 3 — Apply the Terraform root

Run from the `infra/` directory on the infra runner (or bastion):

```bash
cd infra/

terraform init

terraform plan -var-file=environments/prod/prod.tfvars -out=tfplan

terraform apply tfplan
```

The apply will:
1. Create the `external-secrets` Kubernetes namespace.
2. Create an IAM policy scoped to your secret prefix.
3. Create an IRSA role bound to the `external-secrets` service account.
4. Install the operator via Helm (CRDs included).
5. Create the `ClusterSecretStore` CR (`aws-secrets-manager`).

Verify the operator is running:

```bash
kubectl -n external-secrets get pods
# NAME                                               READY   STATUS    RESTARTS
# external-secrets-xxxxxxxxx-xxxxx                   1/1     Running   0
# external-secrets-cert-controller-xxxxxxx-xxxxx     1/1     Running   0
# external-secrets-webhook-xxxxxxx-xxxxx             1/1     Running   0
```

Verify the `ClusterSecretStore` is ready:

```bash
kubectl get clustersecretstore aws-secrets-manager
# NAME                   AGE   STATUS   CAPABILITIES   READY
# aws-secrets-manager    1m    Valid    ReadWrite      True
```

---

## Step 4 — Create a secret in AWS Secrets Manager

Store your secret under the configured prefix:

```bash
aws secretsmanager create-secret \
  --name "node3tier/db-password" \
  --secret-string '{"password":"supersecret"}' \
  --region us-east-2
```

---

## Step 5 — Create an ExternalSecret in your app namespace

Apply this in the `app` namespace (or any namespace):

```yaml
# external-secret-db.yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: db-password
  namespace: app
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager   # ClusterSecretStore created by Terraform
    kind: ClusterSecretStore
  target:
    name: db-password           # name of the Kubernetes Secret to create
    creationPolicy: Owner
  data:
    - secretKey: password       # key in the Kubernetes Secret
      remoteRef:
        key: node3tier/db-password   # Secrets Manager secret name
        property: password           # JSON key inside the secret value
```

```bash
kubectl apply -f external-secret-db.yaml
kubectl -n app get secret db-password -o jsonpath='{.data.password}' | base64 -d
```

---

## Step 6 — Reference the secret in a pod

```yaml
env:
  - name: DB_PASSWORD
    valueFrom:
      secretKeyRef:
        name: db-password
        key: password
```

---

## Outputs

After `terraform apply` these outputs are available:

| Output | Description |
|---|---|
| `external_secrets_irsa_role_arn` | IAM role ARN on the ESO service account |
| `cluster_secret_store_name` | Name of the `ClusterSecretStore` to reference in `ExternalSecret` manifests |

```bash
terraform output external_secrets_irsa_role_arn
terraform output cluster_secret_store_name
```

---

## Troubleshooting

**ClusterSecretStore not Ready**
```bash
kubectl describe clustersecretstore aws-secrets-manager
```
Check the `Status.Conditions` section. Common cause: IRSA role ARN not propagated yet — wait ~30 s and re-check.

**ExternalSecret stuck in `SecretSyncedError`**
```bash
kubectl -n app describe externalsecret db-password
```
Verify the secret name and prefix match what is stored in Secrets Manager, and that the IAM policy prefix covers it.

**IRSA token not working**
```bash
kubectl -n external-secrets get sa external-secrets -o yaml | grep role-arn
```
Confirm the annotation `eks.amazonaws.com/role-arn` is set to the Terraform-created role ARN.
