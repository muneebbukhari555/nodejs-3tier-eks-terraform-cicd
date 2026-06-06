# Edge & Observability — ALB, ACM/TLS, CloudFront, CloudWatch

How the **ingress (ALB)**, **certificates (ACM)**, **CDN (CloudFront)**, and
**observability (CloudWatch)** fit together in this project, and a clear deploy
order. Current as of June 2026 (EKS module v21, AWS provider v6, Helm chart per
tier).

```
                         HTTPS                      HTTPS / HTTP
  Browser ──▶ Route 53 ──▶ CloudFront (CDN, edge) ──▶ ALB (internet-facing) ──┐
              DNS          viewer cert = ACM us-east-1   cert = ACM us-east-2   │ path routing
                                                                               ├── /     ─▶ web Service ─▶ web pods
                                                                               └── /api  ─▶ api Service ─▶ api pods ─▶ RDS

  Every pod (web/api) stdout + node metrics ─▶ CloudWatch Container Insights (amazon-cloudwatch-observability addon)
```

Component → where it lives in the repo:

| Component | Code |
| --------- | ---- |
| ALB (from Ingress) | `helm/web/templates/ingress.yaml` + the **AWS Load Balancer Controller** installed by `infra/terraform/modules/addons` |
| ACM certs | `infra/terraform/modules/acm` (wired in `infra/main.tf`) |
| CloudFront | `infra/terraform/modules/cdn` |
| Observability | `infra/terraform/modules/observability` |

---

## 1. ALB (Ingress) — how it works

There is **one internet-facing ALB** shared by both tiers. We do **not** create
it directly in Terraform — instead:

1. The `addons` module installs the **AWS Load Balancer Controller** (Helm) in
   the cluster, with an IRSA role (keyless).
2. The **`web` Helm chart** renders a Kubernetes **Ingress** (`ingressClassName:
   alb`). The controller watches Ingress objects and **provisions a real AWS
   ALB** to match.

Key annotations (`helm/web/templates/ingress.yaml`):

| Annotation | Meaning |
| ---------- | ------- |
| `scheme: internet-facing` | public ALB (in the public subnets) |
| `target-type: ip` | sends traffic straight to **pod IPs** (no NodePort hop) |
| `group.name: app` | both path rules share **one** ALB instead of two |
| `listen-ports` | `[{"HTTP":80}]`, or `+{"HTTPS":443}` when a cert is set |
| `certificate-arn` | the ACM cert (us-east-2) for TLS **at the ALB** |
| `ssl-redirect: '443'` | force HTTP → HTTPS |

Path routing: `/api` → `api` Service (:3000), `/` → `web` Service (:3000).

Both routes share one ALB via `group.name: app`, but each is defined in a **separate Ingress object** — `helm/api/templates/ingress.yaml` (group order 1) and `helm/web/templates/ingress.yaml` (group order 10). This allows each Ingress to declare its own `healthcheck-path` annotation: `/api/status` for the api target group and `/` for the web target group. Using a shared Ingress with a single health-check path causes 404 failures on the api target group.

**Deploy `api` before `web`** — the web chart's catch-all `/` rule must be registered after the api `/api` rule to ensure correct ALB path priority.

---

## 2. ACM / TLS — why two certificates

TLS uses **AWS Certificate Manager** (free, auto-renewing). You need **two
certs for the same domain** because of a hard AWS rule about *where* each service
reads its cert:

| Cert | Region | Used by | Why |
| ---- | ------ | ------- | --- |
| viewer cert | **us-east-1** | CloudFront | CloudFront is a *global* service; its control plane only reads ACM certs from **us-east-1** |
| origin cert | **us-east-2** | the ALB | an ALB only accepts a cert in **its own region** |

The `acm` module (`infra/terraform/modules/acm`) creates both via **DNS
validation** in Route 53 — the us-east-2 one with the default provider, the
us-east-1 one through an aliased provider (`aws.cloudfront`). It's disabled
(`count = 0`) when `domain_name = ""`, so you can deploy without a domain first.

Outputs: `alb_certificate_arn` (→ the web chart's `ingress.certificateArn`) and
`cloudfront_certificate_arn` (→ the `cdn` module's viewer cert).

---

## 3. CloudFront (CDN) — how it works

CloudFront sits in front of the ALB for global edge caching + TLS offload.
`infra/terraform/modules/cdn`:

- **Origin** = the ALB DNS name (`var.web_alb_dns_name`). It's created **only
  after** the ALB exists (a second apply), so `web_alb_dns_name` is empty on the
  first apply and set afterwards.
- **Viewer protocol** = `redirect-to-https` (browsers always get HTTPS).
- **Origin protocol** = auto: `http-only` when no domain/cert, `https-only`
  (end-to-end TLS) once the viewer cert/domain is configured.
- **Viewer certificate** = the us-east-1 ACM cert when a domain is set, else the
  default `*.cloudfront.net` cert.

Route 53 then points your domain at the CloudFront distribution.

---

## 4. Observability — CloudWatch (logs + metrics)

`infra/terraform/modules/observability` gives centralized logs and metrics with
**no per-node setup**:

- Installs the managed **`amazon-cloudwatch-observability`** EKS add-on →
  deploys **Fluent Bit** (ships every container's stdout/stderr) and the
  **CloudWatch Agent** (Container Insights metrics) as DaemonSets across all 3
  AZs. Auth is **IRSA** (`CloudWatchAgentServerPolicy`) — keyless.
- Creates a CloudWatch **dashboard** `node3tier-overview` (node CPU/mem, running
  pods, RDS CPU/connections, ALB requests/5xx).
- Creates an example **alarm** `node3tier-rds-cpu-high`.

Log groups created (per cluster):

| Log group | Contents |
| --------- | -------- |
| `/aws/containerinsights/node3tier-eks/application` | **web/api stdout/stderr** |
| `/aws/containerinsights/node3tier-eks/dataplane` | kubelet / runtime |
| `/aws/containerinsights/node3tier-eks/host` | node OS |
| `/aws/containerinsights/node3tier-eks/performance` | Container Insights metrics |

```bash
# tail app logs
aws logs tail /aws/containerinsights/node3tier-eks/application --follow --region us-east-2
```

---

## 5. Step-by-step deploy

> Prereq: the cluster, node group, and **core addons (vpc-cni/kube-proxy/coredns)**
> are already up (DEPLOYMENT.md Phase 1–2) and `kubectl get nodes` shows Ready.

### Step 1 — Install the AWS Load Balancer Controller (infra apply)
It's part of `module.addons`, so it's applied with the infra root:
```bash
cd infra && terraform apply -var-file=environments/prod/prod.tfvars
kubectl -n kube-system get deploy aws-load-balancer-controller   # Available
```

### Step 2 — Sync DB secret + deploy the app (creates the Ingress → ALB)
```bash
make secret                       # DB creds into the app namespace
make deploy TAG=bootstrap         # api first, then web (web owns the Ingress)
kubectl -n app get ingress app -w # wait for ADDRESS to appear (~2-3 min)
ALB=$(kubectl -n app get ingress app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
curl -I "http://$ALB" && curl -s "http://$ALB/api/status"
```

### Step 3 — (Optional) custom domain + certs
In `environments/prod/prod.tfvars`:
```hcl
domain_name     = "app.example.com"
route53_zone_id = "Z0123456789ABC"
```
```bash
terraform apply -var-file=environments/prod/prod.tfvars   # creates both ACM certs (DNS-validated)
```
Enable HTTPS on the ALB with the us-east-2 cert:
```bash
helm upgrade --install web ./helm/web -n app --reuse-values \
  --set ingress.certificateArn=$(terraform output -raw alb_certificate_arn)
```

### Step 4 — Put CloudFront in front (second apply)
```bash
# set web_alb_dns_name in prod.tfvars to $ALB, then:
terraform apply -var-file=environments/prod/prod.tfvars
terraform output cloudfront_domain
```
Point Route 53 (`app.example.com`) at the CloudFront domain. Browse it over HTTPS.

### Step 5 — Verify observability
```bash
aws eks list-addons --region us-east-2 --cluster-name node3tier-eks   # includes amazon-cloudwatch-observability
kubectl -n amazon-cloudwatch get pods                                  # fluent-bit + cloudwatch-agent Running
# CloudWatch console → Dashboards → node3tier-overview
```

---

## 6. End-to-end verify

```bash
curl -I https://app.example.com           # 200 via CloudFront (HTTPS)
curl -I http://app.example.com            # 301 → https
curl -s https://app.example.com/api/status
aws logs tail /aws/containerinsights/node3tier-eks/application --since 5m --region us-east-2
```

## 7. Order recap (why this sequence)

1. **LB Controller** (infra) must exist before any Ingress can become an ALB.
2. **App + Ingress** create the ALB (and give you its hostname).
3. **ACM** can be created anytime, but you attach the ALB cert after the ALB and
   the CloudFront cert before the distribution.
4. **CloudFront** needs the ALB hostname → it's the last (second apply).
5. **Observability** is independent (part of infra) and needs only the cluster.
