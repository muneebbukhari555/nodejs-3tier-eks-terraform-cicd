# Self-Hosted Runner Setup — step by step

This is the exact order to bring up the self-hosted runners. The one thing that
trips people up: **a runner EC2 instance, on boot, does `docker run <ECR image>`.
If that image isn't in ECR yet, the instance fails with `manifest unknown`.** So
the image must be built and pushed **before** the runners boot.

```
ordering:
  1. bootstrap apply  ->  creates ECR repo + runner ASGs + SSM token param
  2. put PAT in SSM   ->  runners use it to register to GitHub
  3. build & push image -> the ASGs can now run it
  4. recycle ASGs     ->  instances boot, pull image, register to your repo
```

There are two clean ways to do this. **Path A** avoids the chicken‑and‑egg by
booting the first runners on the public image, then switching to your custom
image. **Path B** is what to do if you already pointed `runner_image` at ECR
(your current situation) — just build/push, then recycle.

---

## Prerequisites (once)

- `aws` CLI logged in (admin), `docker` with buildx (Docker Desktop has it).
- A **GitHub PAT (classic) with `repo` scope** — the runners use it to register.
  (A GitHub App token works too.)

---

## Step 1 — Put the GitHub token in SSM

The bootstrap created the param with a placeholder; set the real value:

```bash
aws ssm put-parameter --region us-east-2 \
  --name /node3tier/runner-registration-token \
  --type SecureString --overwrite \
  --value <YOUR_GITHUB_PAT>
```

---

## Step 2 — Get the ECR repo URL (created by bootstrap)

```bash
cd infra/terraform/bootstrap
REPO=$(terraform output -raw runner_repo_url)   # e.g. 8397...dkr.ecr.us-east-2.amazonaws.com/node3tier/runner
REG=${REPO%/*}                                  # the registry host (strip /node3tier/runner)
echo "$REPO"
```

---

## Step 3 — Build & push the runner image

The runners are **linux/amd64**, so build for that platform (important on Apple
Silicon Macs, which are arm64):

```bash
# from the repo root
aws ecr get-login-password --region us-east-2 \
  | docker login --username AWS --password-stdin "$REG"

docker buildx build --platform linux/amd64 -t "${REPO}:latest" --push ./runner
```

Verify it's there:

```bash
aws ecr list-images --region us-east-2 --repository-name node3tier/runner
```

---

## Step 4 — Point the fleets at the image (only if not already)

In `infra/terraform/bootstrap/terraform.tfvars`:

```hcl
runner_image = "8397....dkr.ecr.us-east-2.amazonaws.com/node3tier/runner:latest"
```

```bash
terraform apply        # in infra/terraform/bootstrap
```

---

## Step 5 — Recycle the runner instances

The already-running instances tried to pull a non-existent image. Replace them so
userdata re-runs against the now-present image:

```bash
aws autoscaling start-instance-refresh --region us-east-2 --auto-scaling-group-name node3tier-infra-runners
aws autoscaling start-instance-refresh --region us-east-2 --auto-scaling-group-name node3tier-app-runners
```

---

## Step 6 — Verify the runners registered

GitHub repo → **Settings → Actions → Runners** — you should see runners labelled
`infra` and `app` as **Idle**. Or:

```bash
gh api repos/<owner>/<repo>/actions/runners --jq '.runners[] | {name, status, labels: [.labels[].name]}'
```

If they don't appear, SSM into one and read the boot log:

```bash
aws ssm start-session --region us-east-2 --target <runner-instance-id>
sudo cat /var/log/cloud-init-output.log | tail -40
```

Common messages and fixes:

| Message | Cause | Fix |
| ------- | ----- | --- |
| `manifest unknown` / image not found | image not pushed yet | Step 3 |
| `denied` on `docker login`/pull | instance role lacks ECR read | it has it; check you pushed to the same account/region |
| `Http response code 401` registering | bad/expired PAT in SSM | re-do Step 1 with a valid `repo`-scope PAT |
| nothing after `docker run` | PAT lacks `repo` scope | use a classic PAT with full `repo` |

---

## How it works (the mental model)

- **`runner/Dockerfile`** is based on `myoung34/github-runner` (a runner image
  that registers itself from env vars) + baked-in terraform/kubectl/helm/aws.
- **bootstrap** creates: the ECR repo for that image, the SSM token param, and
  the two ephemeral runner **ASGs** (`infra`, `app`).
- **userdata** on each instance: log in to ECR → `docker run` the image with
  `REPO_URL` + `ACCESS_TOKEN` (the SSM PAT) + `LABELS` + `EPHEMERAL=1`.
- The container registers to your repo, runs **one** job, deregisters; the ASG
  replaces the instance. Your workflows target them with
  `runs-on: [self-hosted, linux, infra]` or `[self-hosted, linux, app]`.

## Updating the image later (automated)

After the first manual build, the `runner-image.yml` workflow rebuilds and
pushes on changes to `runner/**` (it runs on the `app` runner). Bump the pinned
tool versions in `runner/Dockerfile` to upgrade.
