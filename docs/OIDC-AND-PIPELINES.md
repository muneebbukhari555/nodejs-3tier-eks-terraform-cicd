# Identity Model and CI/CD Pipelines

How every actor in this system authenticates to AWS and to the EKS cluster, and how code moves from a commit to a running deployment.

---

## Identity Model — No Static Keys

This project uses **three distinct keyless identity mechanisms**, one per actor class:

| Actor | Mechanism | Scope |
|---|---|---|
| `infra` self-hosted runner | **EC2 instance role** | Full Terraform: VPC, EKS, RDS, addons, secrets |
| `app` self-hosted runner | **EC2 instance role** | ECR push/pull + `helm upgrade` / `kubectl rollout` |
| In-cluster controllers (LBC, ESO, autoscaler, CloudWatch) | **EKS IRSA** (cluster OIDC) | Least-privilege per-controller IAM role |
| GitHub-hosted quality/SAST jobs | None | No AWS access; runs unit tests and CodeQL only |

**Why no GitHub OIDC?** GitHub OIDC is valuable for granting GitHub-hosted runners a short-lived AWS role. Because *all* AWS-touching jobs in this project run on self-hosted EC2 runners, those instances already have a native AWS identity (the instance role). There is no GitHub-hosted runner that needs an AWS role, so GitHub OIDC has no consumer and is deliberately omitted.

**EKS IRSA** (IAM Roles for Service Accounts) is OIDC — specifically the cluster's own OIDC provider (`oidc.eks.us-east-2.amazonaws.com/…`). It remains active for in-cluster controllers that call AWS APIs (creating load balancers, reading secrets, writing logs, etc.).

---

## Runner Architecture

Two ephemeral runner fleets live in the **management VPC** (10.1.0.0/16), VPC-peered to the workload VPC so they can reach the **private EKS API**:

```
  Management VPC (10.1.0.0/16)               Workload VPC (10.0.0.0/16)
  ┌────────────────────────────────┐  peer   ┌──────────────────────────┐
  │  ASG: node3tier-infra-runners  │◄──────►│  EKS (PRIVATE API)        │
  │    label: infra                │         │  addons, app ns (Helm)   │
  │    → terraform plan/apply      │         └──────────────────────────┘
  │  ASG: node3tier-app-runners    │
  │    label: app                  │
  │    → build/scan/push + helm    │
  │  Bastion (SSM break-glass)     │
  └────────────────────────────────┘
```

- **Ephemeral:** each runner instance registers, runs one job, deregisters, and the ASG recycles it. No state accumulates on a runner.
- **Container-based:** the runner Dockerfile bakes in `terraform`, `kubectl`, `helm`, `docker`, and `aws` CLI at pinned versions.
- **Least-privilege per fleet:** the instance role is per-ASG, so the `app` runner cannot run Terraform and the `infra` runner cannot push to ECR.

See [`docs/RUNNER-ARCHITECTURE-PLAN.md`](RUNNER-ARCHITECTURE-PLAN.md) for the full design rationale and [`docs/RUNNER-SETUP.md`](RUNNER-SETUP.md) for bring-up steps.

---

## CI/CD Pipeline

### Infra pipeline (`infra.yml`)

| Trigger | Job | Runner | Gate |
|---|---|---|---|
| PR touching `infra/**` | `plan` | `infra` (self-hosted) | `plan` environment (no reviewer) |
| Merge to `main` | `apply` | `infra` (self-hosted) | `prod` environment (**required reviewer**) |
| Manual dispatch | `infra-component` (single module) | `infra` (self-hosted) | `prod` |

### App pipeline (`_service-ci.yml`, called by `api-ci.yml` / `web-ci.yml`)

| Stage | Runner | Trigger | Notes |
|---|---|---|---|
| `quality` (unit tests + `npm audit`) | GitHub-hosted | push to `main` or `dev` | No AWS access |
| `codeql` (SAST) | GitHub-hosted | push to `main` or `dev` | No AWS access |
| `build-push` (build → Trivy → ECR push) | `app` (self-hosted) | push to `main` or `dev` | ECR via instance role; fails on HIGH/CRITICAL |
| `deploy` (`helm upgrade` + rollout check) | `app` (self-hosted) | **`main` only** | `prod` environment — pauses for human approval |

### Promotion model

```
  feature/* ──PR──▶ dev ────────────────────▶ build + scan + push (ECR)  [no deploy]
                     │
                     └──PR──▶ main ──────────▶ build + scan + push (ECR)
                                                       │
                                               ⛔ approval gate (prod env)
                                                       │
                                               helm upgrade → rollout status
```

See [`docs/RELEASE-MANAGEMENT.md`](RELEASE-MANAGEMENT.md) for the full branching model, image tagging strategy, and rollback procedure.

---

## EKS Cluster Access

The EKS API is **private** — it accepts connections only from the management VPC CIDR and the workload VPC CIDR (configured in `infra/main.tf` via `api_allowed_cidrs`).

| Actor | Access path | IAM principal |
|---|---|---|
| `infra` runner | VPC peering → private EKS API | `infra_runner_role_arn` (cluster admin) |
| `app` runner | VPC peering → private EKS API | `app_runner_role_arn` (cluster admin) |
| Bastion | SSM session → bastion EC2 → private EKS API | `bastion_role_arn` (cluster admin) |

All three principals are listed in `cluster_admin_principal_arns` in the EKS module and are granted `system:masters` via the EKS access entries API.
