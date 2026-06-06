# Release Management

How code moves from a commit to production for the 3-tier app, with a manual
**approval gate** before any production deploy. Current as of June 2026.

## Branching & promotion model

| Branch | What the pipeline does | Deploys? |
| ------ | ---------------------- | -------- |
| `dev`  | test → CodeQL → build → Trivy scan → **push image to ECR** | ❌ no deploy (artifact only) |
| `main` | test → CodeQL → build → Trivy scan → push image to ECR → **deploy to EKS** | ✅ yes, behind a manual approval gate |

- **`dev`** is the integration branch: every push produces a **scanned, pushed
  image** in ECR (tagged `:<sha>` and the moving `:dev` tag) but **never
  deploys**. This validates the full build/scan/publish path without touching the
  cluster.
- **`main`** is the release branch: merging to it (via PR) runs the same stages,
  then a **gated `Deploy to EKS` job** waits for a human to approve in the
  GitHub `prod` Environment before rolling out with Helm.

```
 feature/* ──PR──▶ dev ────────────────▶ build+scan+push (ECR)         [no deploy]
                    │
                    └──PR──▶ main ──────▶ build+scan+push (ECR) ─▶ ⛔ approval ─▶ Helm deploy
                                                                   (prod env, reviewer)
```

## The pipeline stages (per service: web, api)

Defined in `.github/workflows/_service-ci.yml` (triggered by `web-ci.yml` /
`api-ci.yml` on push to `main` or `dev`, path-filtered):

1. **quality** — `npm test` + `npm audit` (SCA). GitHub-hosted.
2. **codeql** — SAST. GitHub-hosted.
3. **build-push** — build image, **Trivy scan (fails on HIGH/CRITICAL)**, push to
   ECR as `:<git-sha>` plus a channel tag (`:dev` or `:prod`). Runs on the `app`
   self-hosted runner (ECR via instance role; no static keys). **Runs on both
   branches.**
4. **deploy** — `helm upgrade` the per-tier chart, then `kubectl rollout status`.
   **Only on `main`**, and the job declares `environment: prod`, so it **pauses
   for a required reviewer's approval** before it runs.

Infra changes follow the same idea in `infra.yml`: PR → `plan`, merge → `apply`
in the gated `prod` environment.

## The approval gate

The gate is a **GitHub Environment** named `prod` with **Required reviewers**:

- Repo → Settings → Environments → `prod` → enable **Required reviewers** (add
  the release approvers). Optionally add a **wait timer** and restrict to the
  `main` branch.
- Because the `deploy` job sets `environment: prod`, GitHub holds it in
  "Waiting" until an approver clicks **Approve** in the run. Rejecting it cancels
  the deploy. The image is already built/pushed, so approving only releases it —
  nothing is rebuilt.

This gives a clean separation: **build is automatic and continuous; release is a
deliberate human decision.**

## Image tags & traceability

- `:<git-sha>` — immutable, exact provenance for every build (what actually gets
  deployed).
- `:dev` / `:prod` — moving "channel" pointers to the latest image per branch.
- Optionally tag releases with semver (`git tag v1.4.0`) for human-readable
  releases; the deployed artifact is always pinned by `<sha>`.

## Rollback

Deploys are Helm releases, so rollback is one command (run on the bastion or app
runner):

```bash
helm -n app history web                 # list revisions
helm -n app rollback web <REVISION>     # instant rollback to a known-good rev
```

Or re-run the pipeline pointing at a previous good `<sha>` image tag.

## Day-to-day flow

1. Branch from `dev`: `git checkout -b feature/x dev`.
2. Open a PR into `dev`. On merge, the image is built, scanned, and pushed (no
   deploy) — verify it in ECR / CI.
3. Open a PR from `dev` → `main`. Required checks (tests, CodeQL, scan) must pass
   and branch protection enforces review.
4. Merge to `main`. The pipeline rebuilds/scans/pushes, then the **Deploy** job
   waits. An approver opens the run and clicks **Approve**.
5. Helm rolls out with zero downtime; `rollout status` confirms health.

## Setup checklist (one-time)

- [ ] Create the `prod` GitHub Environment with **Required reviewers**.
- [ ] Branch protection on `main` (and `dev`): required status checks =
      `Unit tests & SCA`, `CodeQL (SAST)`, `Build, scan & push (ECR)`; require PR
      review. (See `docs/SECURITY-SETUP.md` / `scripts/setup-branch-protection.sh`.)
- [ ] Self-hosted `app` runners online (see `docs/RUNNER-SETUP.md`).
- [ ] ECR repos `node3tier/web`, `node3tier/api` exist (created by the infra `ecr` module).
