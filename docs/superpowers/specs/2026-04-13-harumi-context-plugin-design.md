# Harumi Context Plugin — Design Spec

**Date:** 2026-04-13
**Status:** Approved
**Scope:** Transform harumi-devops-plugin from a generic multi-provider DevOps plugin into a harumi-specific context-aware plugin with docs sync and drift detection.

## Problem

The plugin currently presents itself as a generic DevOps toolkit with multi-provider abstractions (AWS/GCP/Azure), generic config detection (`.devops.yaml`), and provider-agnostic branching in every skill. This adds complexity without value — harumi runs on AWS, uses ArgoCD, GitHub Actions, and the Prometheus/Loki/Tempo/Grafana stack. The generic layer wastes context tokens and dilutes guidance.

Additionally, documentation across harumi repos drifts out of date when people make changes without using the plugin. There is no mechanism to detect this drift or keep docs in sync with actual infrastructure and cluster state.

## Solution

**Approach: Context Layer.** Keep domain expertise in skills (Terraform patterns, K8s debugging, PromQL references), remove generic multi-provider abstractions, and replace the config system with a `harumi.yaml` manifest that lives in each consuming repo. Add a `sync-docs` skill for documentation maintenance and drift detection on session start.

## Design

### 1. `harumi.yaml` — Repo Config Manifest

Replaces `.devops.yaml` and `config/default.devops.yaml`. Lives at the root of each consuming repo. Contains the actual state of the repo's infrastructure.

```yaml
# Identity
project: harumi
org: harumi-io

# Repositories managed by this plugin
repos:
  infra: harumi-io/infrastructure
  k8s: harumi-io/harumi-k8s

# AWS
aws:
  account_id: "123456789012"
  region: us-east-1
  account_alias: harumi

# Terraform
terraform:
  version: "1.5.7"
  state_backend: s3
  state_bucket: harumi-terraform
  var_file: prod.tfvars
  modules:
    main: /
    core_infra: /core-infrastructure
    iam: /iam

# Kubernetes
clusters:
  - name: eks-prod
    context: eks-prod
    environment: production
    domain: harumi.io
    registry: 123456789012.dkr.ecr.us-east-1.amazonaws.com
  - name: eks-dev
    context: eks-dev
    environment: development
    domain: dev.harumi.io
    registry: 123456789012.dkr.ecr.us-east-1.amazonaws.com

# ArgoCD / GitOps
argocd:
  gitops_repo: harumi-io/harumi-k8s
  app_of_apps:
    prod: eks/bootstrap/eks-app.yaml
    dev: eks-dev/bootstrap/eks-dev-app.yaml

# CI/CD
cicd:
  platform: github-actions

# Containers
containers:
  runtime: docker
  registry: ecr

# Observability — endpoints reachable via kubectl port-forward or ingress
observability:
  metrics: prometheus
  logs: loki
  traces: tempo
  dashboards: grafana
  endpoints:
    prometheus: http://prometheus.monitoring.svc:9090
    grafana: http://grafana.monitoring.svc:3000
    loki: http://loki.monitoring.svc:3100
    tempo: http://tempo.monitoring.svc:3200
    alertmanager: http://alertmanager.monitoring.svc:9093

# Naming
naming:
  pattern: "{namespace}-{stage}-{name}"
  namespace: harumi
  stage: production

# Docs management
docs:
  generated:
    - docs/architecture/*
    - harumi.yaml
  human_authored:
    - README.md
    - CLAUDE.md
    - AGENTS.md
    - docs/runbooks/*
```

**Session-start hook reads `harumi.yaml` from `$PWD`.** If not found, warns: "No harumi.yaml found. Run the sync-docs skill to generate one."

Skills consume config values from the injected context at session start — same mechanism as before, different config shape.

### 2. Drift Detection on Session Start

A `.harumi-last-sync` file (gitignored) tracks the last known state:

```
commit=5ff64aa
timestamp=2026-04-13T14:30:00Z
```

**Session-start flow:**

```
Session starts
    |
    +-- Read harumi.yaml
    |   +-- Not found? -> Warn and skip drift check
    |
    +-- Read .harumi-last-sync
    |   +-- Not found? -> First run, write current state, skip drift check
    |
    +-- Compare saved commit SHA with current HEAD
    |   +-- Same? -> No drift, proceed normally
    |
    +-- Drift detected -> git log --oneline <saved>..HEAD
    |   |
    |   +-- Classify changed files:
    |   |   +-- Generated docs (docs/architecture/*, harumi.yaml) -> auto-update silently
    |   |   +-- Human-authored docs (README, CLAUDE.md, etc.) -> flag for review
    |   |
    |   +-- Inject drift summary into context:
    |   |   "X commits since last session. Changes in: [dirs].
    |   |    Auto-updating docs/architecture/. README.md may need review."
    |   |
    |   +-- Update .harumi-last-sync with current HEAD
    |
    +-- Inject bootstrap skill + config as usual
```

**Division of labor:**
- The **hook** (bash) detects drift and injects a summary. It is fast — just `git log` and file path classification.
- The **`sync-docs` skill** does the actual doc updates. The bootstrap skill triggers it when drift is detected.

**Why not auto-run sync-docs from the hook?** Cluster queries (`kubectl get`, `argocd app list`) can be slow and might fail if VPN is down. The AI can handle retries, skip gracefully, and prompt the user.

### 3. `sync-docs` Skill

Replaces `setup-devops-config`. Maintains repo documentation by reading actual code, infrastructure state, and cluster state.

**Targets:**

| Target | Source of Truth | Classification |
|--------|----------------|----------------|
| `harumi.yaml` | Terraform files, K8s manifests, cluster state | Generated (auto-update) |
| `docs/architecture/clusters.md` | Live cluster state | Generated (auto-update) |
| `docs/architecture/services.md` | ArgoCD apps, Helm releases, deployments | Generated (auto-update) |
| `docs/architecture/infrastructure.md` | Terraform state, modules | Generated (auto-update) |
| `docs/architecture/networking.md` | Ingresses, services, domains | Generated (auto-update) |
| `docs/architecture/observability.md` | Monitoring stack state | Generated (auto-update) |
| `README.md` | All of the above | Human-authored (prompt first) |
| `CLAUDE.md` | Repo structure, commands, conventions | Human-authored (prompt first) |
| `AGENTS.md` | Infrastructure modules, operational context | Human-authored (prompt first) |
| `docs/runbooks/*` | Operational state changes | Human-authored (prompt first) |

**Skill flow:**

```
sync-docs triggered
    |
    +-- Step 1: Scan repos
    |   +-- Read Terraform files (modules, resources, outputs)
    |   +-- Read K8s manifests (harumi-k8s repo)
    |   +-- Read CI/CD workflows
    |
    +-- Step 2: Query live cluster state (read-only)
    |   +-- kubectl get namespaces,deployments,services,ingress --all-namespaces
    |   +-- argocd app list --output json
    |   +-- helm list --all-namespaces
    |   +-- kubectl get pods -n monitoring (observability stack health)
    |   ! If kubectl unavailable -> skip, note in output, proceed with repo-only data
    |
    +-- Step 3: Update generated docs
    |   +-- Diff each generated file against new state
    |   +-- Write changes silently (no prompt)
    |   +-- Update .harumi-last-sync
    |
    +-- Step 4: Check human-authored docs
    |   +-- Compare current state against what each doc claims
    |   +-- Identify stale sections
    |   +-- For each stale doc:
    |       "README.md line 42 says 'two EKS clusters' but there are now three.
    |        Proposed edit: [show diff]. Apply? (yes / skip)"
    |
    +-- Step 5: Summary
        "Updated: docs/architecture/clusters.md, services.md, harumi.yaml
         Proposed: 2 edits to README.md (1 applied, 1 skipped)
         Skipped: CLAUDE.md, AGENTS.md (no drift detected)"
```

**Trigger conditions:**
1. Automatically on session start when drift is detected (bootstrap skill triggers it)
2. Manually when user asks to sync/update docs
3. Suggested after user executes a handoff (post-apply)

### 4. Skill Cleanup — Removing Generic Abstractions

**Remove across all skills:**

| Remove | Reason |
|--------|--------|
| Multi-provider branching (aws/gcp/azure) | AWS-only, from `harumi.yaml` |
| `.devops.yaml` references and config detection | Replaced by `harumi.yaml` |
| `setup-devops-config` skill (entire directory) | Replaced by `sync-docs` |
| Generic registry options (ecr/gcr/dockerhub/ghcr) | ECR only |
| Generic gitops options (argocd/flux/none) | ArgoCD only |
| Generic CI/CD platform branching | GitHub Actions only |
| Generic K8s tool options (kubectl/oc) | kubectl only |
| Generic observability options (datadog/cloudwatch) | Prometheus/Loki/Tempo/Grafana only |
| `config/default.devops.yaml` | No longer needed |
| "Future skills" list in bootstrap skill | Either built or not |

**Keep unchanged:**
- All domain knowledge in skills (Terraform patterns, K8s debugging trees, PromQL/LogQL/TraceQL references, ArgoCD sync wave patterns)
- All reference files (`skills/*/references/`)
- All agents in `agents/` (thin wrappers, no config logic)
- All operations command skills (IAM, VPN, deploy-app, namespace, etc.)
- All eval scenarios (`skills/*/evals/`)
- Safety rules and handoff patterns
- `eval-viewer/` and `scripts/`

**Add to bootstrap skill (`using-devops`):**
- Multi-repo awareness: manages `harumi-io/infrastructure` and `harumi-io/harumi-k8s`
- Cluster read-access rules:
  - Allowed: `kubectl get`, `kubectl describe`, `kubectl logs`, `kubectl top`, `argocd app get`, `argocd app list`, `helm list`, `helm get values`
  - Forbidden: `kubectl apply`, `kubectl delete`, `kubectl edit`, `kubectl patch`, `helm install/upgrade`, `argocd app sync` — all writes go through handoff
- Drift detection trigger: "If drift was detected at session start, invoke sync-docs before other work"
- Observability endpoints from config

### 5. File Changes Summary

**Delete:**
- `config/default.devops.yaml`
- `skills/setup-devops-config/` (entire directory)

**Create:**
- `skills/sync-docs/SKILL.md`
- `docs/architecture/clusters.md`
- `docs/architecture/services.md`
- `docs/architecture/infrastructure.md`
- `docs/architecture/networking.md`
- `docs/architecture/observability.md`
- `docs/runbooks/` (empty directory, ready for human-authored runbooks)
- `.harumi-last-sync` entry in `.gitignore`

**Modify:**
- `hooks/session-start` — read `harumi.yaml`, add drift detection
- `skills/using-devops/SKILL.md` — remove generic refs, add multi-repo awareness, cluster read-access rules, drift trigger, observability endpoints, replace `setup-devops-config` trigger with `sync-docs`
- `skills/infrastructure/SKILL.md` + references — remove GCP/Azure branching, assume AWS
- `skills/kubernetes/SKILL.md` + references — remove `oc` option, assume kubectl, add live cluster query guidance
- `skills/argocd/SKILL.md` + references — remove generic gitops options, hardwire ArgoCD
- `skills/observability/SKILL.md` + references — remove Datadog/CloudWatch/Jaeger, assume Prometheus/Loki/Tempo/Grafana, add endpoints from config
- `skills/deploy-app/SKILL.md` + references — remove generic CI branching, assume GitHub Actions
- Operations command skills — remove generic provider references
- `package.json` — bump version
- `README.md` — update to reflect new architecture
- `CHANGELOG.md` — add entry

**Unchanged:**
- `skills/*/references/` domain knowledge content
- `agents/` (thin wrappers)
- `skills/*/evals/`
- `eval-viewer/`, `scripts/`

### 6. Repo Interaction Model

```
harumi-devops-plugin (this repo)
    |
    +-- Installed into consuming repos via /plugin
    |
    +-- On session start:
    |   +-- Reads harumi.yaml from consuming repo
    |   +-- Checks .harumi-last-sync for drift
    |   +-- Injects bootstrap skill + config + drift summary
    |
    +-- Knows about two managed repos:
    |   +-- harumi-io/infrastructure -> Terraform IaC
    |   +-- harumi-io/harumi-k8s -> K8s manifests, ArgoCD
    |
    +-- Uses local kubectl contexts for read-only cluster access
    |
    +-- sync-docs maintains documentation accuracy:
        +-- Generated docs: auto-updated silently
        +-- Human-authored docs: proposed edits with user approval
```
