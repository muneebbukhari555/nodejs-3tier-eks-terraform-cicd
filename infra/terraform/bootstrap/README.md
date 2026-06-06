# Bootstrap (trust anchor)

Run **once**, locally, by an admin, **before** anything else. It creates the
prerequisites that the pipelines depend on — none of which need the workload
cluster:

1. **Remote state backend** — S3 bucket (versioned, encrypted, private) with
   native S3 locking (`use_lockfile`, Terraform 1.11+). No DynamoDB.
2. **Management VPC + bastion** (SSM) + private subnets & NAT.
3. **Two ephemeral, container-based runner FLEETS** (ASGs) in the mgmt VPC, each
   with its own least-privilege **instance role**:
   - `node3tier-infra-runner-role` — Terraform (label `self-hosted,linux,infra`)
   - `node3tier-app-runner-role` — build/scan/push + helm (label `self-hosted,linux,app`)
4. An **SSM SecureString** holding the runner registration token (GitHub App
   token / PAT), set out-of-band after apply.

No GitHub OIDC and no IAM web-identity roles, runners use their instance roles.

## Run it

```bash
cd infra/terraform/bootstrap
cp terraform.tfvars.example terraform.tfvars   # github_owner/repo, region, AZs
terraform init
terraform apply

# Provide the runner registration token (GitHub App token or PAT, repo admin):
aws ssm put-parameter --name /node3tier-prod/runner-registration-token \
  --type SecureString --overwrite --value <token>

# Migrate this stack's own state into the bucket it just created:
#   uncomment the backend block in versions.tf, fill the bucket, then:
terraform init -migrate-state
```

## Wire the outputs into the infra root

```bash
terraform output
```

- `state_bucket` → `infra/backend.tf` `bucket`.
- `mgmt_vpc_id`, `mgmt_vpc_cidr`, `mgmt_route_table_ids`, `bastion_role_arn`,
  `infra_runner_role_arn`, `app_runner_role_arn` → `infra/environments/prod/prod.tfvars`.

## GitHub Environments (approval gates)

Create **`prod`** (required reviewer) and **`plan`** (no reviewer). They gate the
infra apply and app deploy with human approval. No environment *secrets* are
needed (identity is the runner instance roles).
