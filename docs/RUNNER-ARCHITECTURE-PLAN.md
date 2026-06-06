# Runner Architecture (Implemented)

> **Status: IMPLEMENTED.** This is the design in the repo. DEPLOYMENT.md is the
> operational single source of truth; this file explains the *why*.

## Problem

A **private** EKS API means CI must run inside the VPC. In-cluster runners (ARC)
can't create the cluster that hosts them (bootstrap paradox). The fix: run CI on
**self-hosted runners that live outside the workload cluster** — in the
management VPC, peered to it.

## Design: two ephemeral, container-based runner fleets (no ARC, no GitHub OIDC)

```
 Management VPC (10.1/16)                         Workload VPC (10.0/16)
 ┌───────────────────────────────┐  peering  ┌──────────────────────────────┐
 │ ASG `infra`  (instance role)   │<========> │ EKS (PRIVATE API)            │
 │   ephemeral, container runner  │           │  addons (IRSA), app ns,      │
 │   → terraform plan/apply       │           │  web/api (Helm), RDS, ECR    │
 │ ASG `app`    (instance role)   │           └──────────────────────────────┘
 │   → build/scan/push + helm     │
 │ bastion (SSM)   NAT → egress   │
 └───────────────────────────────┘
```

- **Container-based, ASG-backed, ephemeral:** each job runs on a fresh instance
  that pulls a runner image (terraform/kubectl/helm/docker/aws baked in),
  registers as an ephemeral runner, runs one job, and is recycled. Scale via ASG
  count (0→N across AZs).
- **Two fleets for least privilege:** the IAM identity is the **instance role**,
  which is per-ASG. `infra` = broad deploy; `app` = ECR + cluster rollout only.
- **Peered to the workload VPC**, and the EKS API allows the mgmt CIDR, so both
  fleets reach the **private** API — no tunnel, no public endpoint.

## Identity model (keyless)

| Workload | Identity | Why |
| -------- | -------- | --- |
| `infra` runner | EC2 instance role | native identity of an instance |
| `app` runner | EC2 instance role | ECR push + cluster rollout |
| in-cluster addons | **EKS IRSA (cluster OIDC)** | controllers' AWS access |
| GitHub-hosted quality/SAST | none | no AWS access |

**On OIDC:** GitHub-OIDC adds value only for *GitHub-hosted* runners (which have
no AWS identity). With everything self-hosted, identity is the instance role, so
GitHub-OIDC has no consumer and is removed. **EKS IRSA — which *is* OIDC, via the
cluster's own provider — stays** for in-cluster controllers.

## What runs where

| Job | Runner | Identity |
| --- | ------ | -------- |
| Terraform plan/apply | `infra` (self-hosted) | instance role |
| App build → Trivy → push ECR | `app` (self-hosted) | instance role |
| App `helm`/`kubectl` deploy | `app` (self-hosted) | instance role + cluster RBAC |
| Unit tests, npm audit, CodeQL | GitHub-hosted | none (no AWS) |

## Bootstrap = the one manual step

Run once, locally, by an admin (`infra/terraform/bootstrap`): state backend +
mgmt VPC + bastion + both runner fleets + the SSM registration token. Everything
after that is automated on the runners it created.

## Security highlights

- Ephemeral runners (fresh per job), **IMDSv2 required**, **egress-only SGs**.
- Private control plane; API reachable only from the mgmt VPC.
- Least-privilege per-fleet instance roles; no static keys anywhere.
- Branch protection + gated `prod` environment (human approval) for apply/deploy.
- Trivy (image + IaC), CodeQL, npm audit, Gitleaks, Checkov gates.
