# Security & Branch-Protection Setup

This document describes how `main` is protected and how the repository's
production-grade security controls are configured. It is written so a reviewer
can verify each control in the GitHub UI.

---

## 0. Prerequisite: rename the default branch to `main`

The CI workflows trigger on `branches: [main]`, so the default branch must be
`main` (the repo was initialised as `master`):

```bash
git branch -m master main
git push -u origin main
# On GitHub: Settings → Branches → set "main" as default, then:
git push origin --delete master
```

---

## 1. Repository security features

Enable under **Settings → Code security and analysis** (or run
`scripts/setup-branch-protection.sh`):

| Feature | Setting |
| ------- | ------- |
| Dependency graph | Enabled |
| Dependabot alerts | Enabled |
| Dependabot security updates | Enabled |
| Dependabot version updates | Enabled (`.github/dependabot.yml`) |
| Secret scanning | Enabled |
| Secret scanning **push protection** | Enabled |
| Private vulnerability reporting | Enabled |
| CodeQL (default/advanced) | Advanced — see `.github/workflows/_service-ci.yml` |

> On **public** repos these are free. CodeQL/secret scanning on private repos
> require GitHub Advanced Security.

### Merge hygiene (Settings → General → Pull Requests)

- ✅ Allow squash merging — ❌ merge commits — ❌ rebase merging
- ✅ Automatically delete head branches
- ✅ Always suggest updating PR branches

---

## 2. Branch protection ruleset for `main`

Configured at **Settings → Branches → Add rule** (or via the script). Controls:

| Control | Value | Why |
| ------- | ----- | --- |
| Require a pull request before merging | ✅ | No direct pushes to `main` |
| Required approvals | **1** | Peer review |
| Dismiss stale approvals on new commits | ✅ | Re-review after changes |
| Require review from Code Owners | ✅ | `.github/CODEOWNERS` |
| Require approval of the most recent push | ✅ | Author can't self-approve their last change |
| Require status checks to pass | ✅ | CI gate |
| Require branches up to date before merge | ✅ (`strict`) | No stale merges |
| Require conversation resolution | ✅ | No unresolved review threads |
| Require signed commits | ✅ | Commit authenticity |
| Require linear history | ✅ | Clean, auditable history |
| Block force pushes | ✅ | History integrity |
| Block deletions | ✅ | Can't delete `main` |
| Include administrators | ✅ (`enforce_admins`) | Rules apply to everyone |

### Required status checks (must match CI job names)

- `Unit tests & SCA` — unit tests + `npm audit` (SCA)
- `CodeQL (SAST)` — static analysis
- `Gitleaks` — secret scan

> Status-check contexts only appear in the picker **after** the workflow has
> run at least once. Open one PR first, then add the checks.
>
> ⚠️ Because `web`/`api` CI call a **reusable** workflow, GitHub reports the
> checks with the caller job prefixed, e.g. `api / Unit tests & SCA` and
> `web / CodeQL (SAST)`. Use the exact names shown on a real PR's checks tab,
> and update the `checks[].context` values in
> `scripts/setup-branch-protection.sh` to match.

---

## 3. Apply it automatically

```bash
# Authenticated gh CLI with admin on the repo:
./scripts/setup-branch-protection.sh <owner>/node-3tier-app2
```

This enables the repo security features and applies the full `main` ruleset
above in one shot. Re-running is safe (idempotent).

---

## 4. What's enforced in CI (defense in depth)

| Layer | Tool | Location |
| ----- | ---- | -------- |
| SAST | CodeQL | `_service-ci.yml` |
| SCA (deps) | `npm audit` + Dependabot | `node-quality` action, `dependabot.yml` |
| Container scan | Trivy | `docker-build-scan-push` action |
| IaC scan | Trivy/tfsec | `terraform-ci.yml` |
| Secret scan | Gitleaks + push protection | `gitleaks.yml` |
| Supply chain | OpenSSF Scorecard | `scorecard.yml` |
| Cloud auth | GitHub OIDC → AWS IAM (no static keys) | `setup-aws` action |
| Least privilege | scoped `permissions:` per workflow | all workflows |

---

## 5. Recommended hardening checklist (org/account level)

- [ ] Require 2FA for all collaborators (Org → Settings → Authentication)
- [ ] Pin third-party actions to a commit SHA (Dependabot keeps them updated)
- [ ] Restrict `GITHUB_TOKEN` default permissions to read-only
      (Settings → Actions → General → Workflow permissions)
- [ ] Require approval for first-time contributors' workflow runs
- [ ] Add a Scorecard badge to `README.md`
- [ ] Enable tag protection for release tags (`v*`)
