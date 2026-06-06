# CDN (CloudFront) + ALB Ingress + TLS

How the edge fits together and where TLS is terminated, end to end.

```
                         (1) DNS                 (2) HTTPS 443
  End user  ───────────▶  Route 53  ──────────▶  CloudFront  ─────────────┐
                                                  (viewer TLS,             │
                                                   ACM cert in us-east-1)  │
                                                                          │ (3) HTTPS/HTTP to origin
                                                                          ▼
                                                                  ALB (internet-facing)
                                                                  created by the AWS Load
                                                                  Balancer Controller from
                                                                  the Helm Ingress object
                                                                          │ (4) HTTP to pods
                                                                 ┌────────┴────────┐
                                                                 / (web)        /api (api)
```

## 1. Who creates the ALB

The ALB is **not** created directly by Terraform. The **`web` Helm chart**
(`helm/web`) renders a Kubernetes **Ingress** with `ingressClassName: alb`
(routing `/` → web and `/api` → the api Service). The **AWS Load
Balancer Controller** (installed by the `addons` Terraform module) watches
Ingress objects and provisions a real AWS ALB to match, including target
groups that point straight at pod IPs (`target-type: ip`).

Relevant annotations (in `helm/web/templates/ingress.yaml`):

| Annotation | Effect |
| ---------- | ------ |
| `scheme: internet-facing` | public ALB |
| `group.name: app` | both Ingress objects share ONE ALB (api: order 1, web: order 10) |
| `target-type: ip` | route to pod IPs (no NodePort hop) |
| `healthcheck-path` | per-Ingress: `/api/status` for api, `/` for web |
| `listen-ports` | which listeners (80, and 443 if a cert is set) |
| `certificate-arn` | ACM cert for TLS termination at the ALB |
| `ssl-redirect: '443'` | force HTTP→HTTPS |

> **Note:** The `/api` and `/` routes are defined in separate Ingress objects (api chart and web chart respectively) joined by `group.name: app`. This allows each service to declare its own `healthcheck-path`, preventing the 404 health-check failure that occurs when a single catch-all path is used across both target groups.

## 2. Two valid TLS topologies

### A) TLS at CloudFront (CDN is the front door) — recommended

- **Viewer → CloudFront:** HTTPS. The certificate is an **ACM cert in
  `us-east-1`** (CloudFront only reads certs from us-east-1, regardless of where
  the rest of the stack lives — here `us-east-2`). Attach it as the CloudFront
  *viewer certificate* and put your domain in *aliases*.
- **CloudFront → ALB (origin):** the `cdn` module auto-selects the origin
  policy — `http-only` when no domain is set, `https-only` (end-to-end TLS) once
  a viewer cert/domain is configured. For full encryption also set the ALB's own
  cert (us-east-2) via the web chart's `ingress.certificateArn`.
- DNS: Route 53 ALIAS/CNAME for your domain → the CloudFront distribution
  domain (`dxxxx.cloudfront.net`).

### B) TLS at the ALB only (no CDN, or CDN passthrough)

- Set `ingress.certificateArn` in `helm/web/values.yaml` to an **ACM cert in
  `us-east-2`** (same region as the ALB). The chart then opens an HTTPS:443
  listener and redirects 80→443.
- Route 53 → the ALB hostname directly (or CloudFront with an HTTPS origin).

> **Why two certs / why us-east-1?** CloudFront is a *global* AWS service whose
> control plane lives in **us-east-1**, so it only reads ACM certificates from
> us-east-1 — even though our ALB/EKS/RDS all run in us-east-2. An ALB, by
> contrast, only accepts a cert from **its own region (us-east-2)**. Same domain,
> two certs, because two different services each have a fixed region requirement.
> ACM is free and auto-renews, so this costs nothing.

## 3a. Automated path (Terraform `acm` module)

This is now codified. Set a domain + hosted zone in `prod.tfvars` and the root
creates **both** certs (us-east-1 for CloudFront via an aliased provider,
us-east-2 for the ALB), DNS-validates them in Route 53, and wires the CloudFront
viewer cert automatically:

```hcl
# infra/environments/prod/prod.tfvars
domain_name     = "app.example.com"
route53_zone_id = "Z0123456789ABC"
```

`module.acm` outputs `alb_certificate_arn` (us-east-2) and
`cloudfront_certificate_arn` (us-east-1). The CloudFront one feeds `module.cdn`;
pass the ALB one to the web Helm chart's `ingress.certificateArn` for HTTPS at
the ALB. Leave `domain_name = ""` to skip ACM (CloudFront uses its default cert).

## 3b. Manual path (if you prefer)

1. **Request ACM certificates** (DNS-validated):
   - One in **us-east-2** for the ALB (topology A origin, or topology B).
   - One in **us-east-1** for CloudFront (topology A viewer).
   ```bash
   aws acm request-certificate --domain-name app.example.com \
     --validation-method DNS --region us-east-2
   aws acm request-certificate --domain-name app.example.com \
     --validation-method DNS --region us-east-1
   ```
   Create the validation CNAMEs in Route 53; wait for `ISSUED`.

2. **Terminate TLS at the ALB** — set the us-east-2 cert ARN:
   ```bash
   helm upgrade --install web ./helm/web -n app --reuse-values \
     --set ingress.certificateArn=arn:aws:acm:us-east-2:<ACCT>:certificate/<id>
   ```
   The ALB now serves HTTPS:443 and redirects HTTP→HTTPS.

3. **Put CloudFront in front** — capture the ALB hostname and run the second
   Terraform apply (the `cdn` module). For end-to-end TLS, set the origin to
   `https-only` and attach the us-east-1 viewer cert + alias (extend
   `modules/cdn/variables.tf` with `viewer_certificate_arn` and `aliases`).
   ```bash
   ALB=$(kubectl -n app get ingress app -o jsonpath='{.status.loadBalancer.ingress[0].hostname}')
   terraform apply -var="web_alb_dns_name=$ALB"
   terraform output cloudfront_domain
   ```

4. **DNS** — point `app.example.com` (Route 53) at the CloudFront domain.

## 4. Why this layering

- **CloudFront** gives global edge caching, TLS offload, and a stable anycast
  edge; it shields the ALB and can host WAF.
- **ALB** does L7 path routing (`/` vs `/api`) and health checks straight to
  pods; the LB Controller keeps it in sync with the Ingress automatically.
- **ACM** issues/renews certs for free; no private keys are handled manually.

## 5. Verify

```bash
curl -I https://app.example.com           # 200 via CloudFront (HTTPS)
curl -I http://app.example.com            # 301 -> https (ssl-redirect)
curl -s https://app.example.com/api/status
```

> Quick reference: the same flow is summarised in DEPLOYMENT.md Phases 4–5.
