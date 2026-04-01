# Kubernetes & ArgoCD Skills Design

**Date:** 2026-04-01
**Status:** Approved
**Scope:** Two domain skills (`kubernetes`, `argocd`) + five operation commands (`deploy-app`, `create-namespace`, `rollback-deployment`, `debug-pod`, `scale-deployment`) + config extensions + bootstrap updates

---

## 1. Overview

Add Kubernetes and ArgoCD support to the harumi-devops-plugin as generic, config-driven skills. This replaces the repo-specific `argocd-app` skill currently in `harumi-k8s/.claude/skills/` with a portable plugin skill that derives repo context from `.devops.yaml`.

### Design Principles

- **Config-driven**: all repo/cluster-specific details come from `.devops.yaml`, never hardcoded
- **Inspect before acting**: always query actual cluster state before creating or modifying anything; never guess
- **Update references when reality differs**: if cluster state doesn't match documented patterns, update reference files
- **Safety rules apply to ALL environments equally**: no "dev is safe" shortcuts
- **Handoff pattern for all mutations**: never execute destructive commands, always provide the exact command for the user
- **ArgoCD only**: no Flux support (reserved for future)

---

## 2. Skill Architecture

```
skills/
├── kubernetes/                        # Core K8s skill
│   ├── SKILL.md
│   └── references/
│       ├── workflow.md                # Operational phases, handoff templates
│       ├── manifests.md               # Manifest authoring, Helm values patterns
│       ├── security.md                # RBAC, NetworkPolicy, pod security, secrets
│       ├── debugging.md               # Troubleshooting decision trees
│       └── examples.md               # YAML snippets (config-driven naming)
├── argocd/                            # ArgoCD skill
│   ├── SKILL.md
│   └── references/
│       ├── app-patterns.md            # 3 deployment patterns
│       ├── sync-waves.md              # Wave ordering, hooks, health checks
│       └── examples.md               # ArgoCD Application YAMLs
├── deploy-app/SKILL.md               # Operation: onboard app to ArgoCD
├── create-namespace/SKILL.md          # Operation: namespace + RBAC + quotas
├── rollback-deployment/SKILL.md       # Operation: rollback with safety checks
├── debug-pod/SKILL.md                 # Operation: guided pod troubleshooting
└── scale-deployment/SKILL.md          # Operation: scale with safety checks
```

### Trigger Split

- **`kubernetes`** triggers on: K8s manifests (`.yaml` with apiVersion/kind), Helm charts, kubectl operations, pod issues, RBAC, network policies, scaling discussions, resource limits
- **`argocd`** triggers on: ArgoCD Applications, sync/drift issues, app-of-apps patterns, GitOps deployment, onboarding services to ArgoCD
- **Operations** trigger on their specific verbs (deploy, create namespace, rollback, debug pod, scale)

---

## 3. Core `kubernetes` Skill

### Workflow Phases

1. **Consult** — read `.devops.yaml` for cluster context, tool preferences, naming patterns
2. **Verify** — check current cluster state with `kubectl` before any changes
3. **Implement** — write/modify manifests, Helm values, RBAC configs
4. **Validate** — `kubectl apply --dry-run=client`, schema validation, lint
5. **Handoff** — never `kubectl apply` directly; provide exact commands for the user
6. **Confirm** — provide verification commands to run after apply

### Safety Rules (ALL Environments)

These rules apply equally to production, staging, development, and any other environment:

- Never run `kubectl apply`, `kubectl delete`, `kubectl patch`, or any write operation without explicit user confirmation
- Never run `kubectl exec` with destructive commands
- Read-only commands are always safe: `get`, `describe`, `logs`, `top`, `events`
- Always verify namespace and context before any write operation
- Always inspect what exists in the cluster before creating anything
- If cluster state differs from reference documentation, update the references first

### Handoff Template

```
Configuration ready for deployment!

Please review the manifest(s), then execute:
kubectl apply -f [file] --context [context] -n [namespace]

What this will do:
- [summary of changes]

Verification:
kubectl get [resource] -n [namespace] --context [context]
[additional verification commands]
```

### References

#### `workflow.md`
Detailed operational phases with pre/post verification patterns. Includes templates for handoff messages, verification command sets per resource type, and rollback procedures.

#### `manifests.md`
Manifest authoring patterns for common resources:
- Deployment (rolling update, resource limits, probes, topology spread)
- Service (ClusterIP, LoadBalancer, headless)
- Ingress (ALB, nginx, with TLS from config)
- ConfigMap and Secret patterns
- PersistentVolumeClaim
- HorizontalPodAutoscaler
- PodDisruptionBudget
- Helm values best practices (override patterns, value precedence)

#### `security.md`
- RBAC: Role, ClusterRole, RoleBinding, ClusterRoleBinding patterns
- NetworkPolicy: ingress/egress rules, namespace isolation
- Pod Security Standards (restricted, baseline, privileged)
- Secret management: External Secrets Operator, sealed-secrets patterns
- ServiceAccount token management

#### `debugging.md`
Decision tree for pod failures:
- **Pending**: node capacity, affinity/taints, PVC binding
- **CrashLoopBackOff**: logs (current + previous), exit codes, resource limits
- **ImagePullBackOff**: registry auth, image tag, ECR token expiry
- **OOMKilled**: memory limits, actual usage via `kubectl top`
- **Evicted**: disk pressure, node conditions
- **Terminating stuck**: finalizers, force delete considerations

Diagnostic sequence: pod status → events → logs → describe → node conditions.

#### `examples.md`
Ready-to-use YAML snippets using `.devops.yaml` naming patterns (`{namespace}-{stage}-{name}`). Config-driven: cluster domain, registry URL, namespace from config.

---

## 4. `argocd` Skill

### Deployment Patterns

#### 1. Application Deployment
Deploy a new application with its own repository, CI/CD pipeline, and container image.

**What the skill generates:**
- Dockerfile (if not present)
- GitHub Actions workflow for build/push to ECR
- ArgoCD Application manifest in the K8s repo
- Helm chart or Kustomize overlay with values
- Namespace resources if needed

**Before creating:** inspect existing ArgoCD apps (`argocd app list`), check if namespace exists, verify ECR repository.

#### 2. Cluster Service
Deploy an off-the-shelf Helm chart as cluster infrastructure (monitoring stack, ingress controller, cert-manager, etc.).

**Key patterns:**
- Two-source pattern: Helm chart from upstream repo + values from K8s repo
- Parent app for grouping related services (e.g., monitoring parent app)
- Sync wave ordering for dependencies
- `ServerSideApply` for CRDs
- `RespectIgnoreDifferences` for auto-populated fields

**Before creating:** inspect existing Helm releases (`helm list`), check for CRD conflicts, verify chart availability.

#### 3. Helm Adoption
Onboard an existing Helm release already running in the cluster into ArgoCD management.

**Steps:**
- Export current values (`helm get values`)
- Create ArgoCD Application manifest pointing to the same chart/version
- Verify sync status shows no drift
- Transition ownership to ArgoCD

**Before creating:** inspect the running release, compare values, check for manual modifications.

### References

#### `app-patterns.md`
Detailed steps for each pattern with config-driven placeholders. Includes directory structure conventions, naming patterns, and the full file set generated for each pattern.

#### `sync-waves.md`
- Wave ordering conventions: wave 0 (namespaces, secrets, configmaps), wave 1 (independent backends), wave 2 (dependent services), wave 3+ (consumers)
- Sync hooks (PreSync, Sync, PostSync, SyncFail)
- Health check customization
- Retry policies
- `ServerSideApply` and `RespectIgnoreDifferences` guidance

#### `examples.md`
ArgoCD Application YAML examples for each pattern, AppProject examples, multi-source configuration.

### Safety Rules (in addition to core kubernetes rules)

- Never run `argocd app sync`, `argocd app delete`, or `argocd app patch` without user confirmation
- Always verify app health and sync status before and after changes
- Handoff pattern for all ArgoCD mutations
- Inspect existing ArgoCD apps before creating new ones

---

## 5. Operation Commands

### Universal Rules (All Operations)

- **Inspect before acting** — always check what exists in the cluster first
- **Update references if reality differs** — if cluster state doesn't match documented patterns, update reference files
- **Same safety for all environments** — no exceptions
- **Handoff for all mutations** — provide the command, never execute

### `deploy-app`

Onboard a new application to ArgoCD. References the `argocd` skill.

**Flow:**
1. Ask which deployment pattern (application deployment, cluster service, helm adoption)
2. Ask target cluster (from `.devops.yaml` clusters list)
3. Inspect cluster: existing apps, namespaces, Helm releases
4. Generate all manifests based on chosen pattern
5. Register in app-of-apps structure
6. Provide handoff with apply commands and verification

### `create-namespace`

Create a namespace with associated resources. References the `kubernetes` skill.

**Flow:**
1. Ask namespace name and target cluster
2. Check if namespace already exists (`kubectl get ns`)
3. List existing namespaces for context
4. Generate: Namespace, ResourceQuota, LimitRange, NetworkPolicy, RBAC RoleBindings
5. If ArgoCD is configured, generate ArgoCD Application for the namespace resources
6. Provide handoff with apply commands

### `rollback-deployment`

Roll back a deployment to a previous revision. References the `kubernetes` skill.

**Flow:**
1. Ask deployment name, namespace, target cluster
2. Inspect current rollout status (`kubectl rollout status`)
3. Show revision history (`kubectl rollout history`)
4. Show diff between current and target revision
5. Provide `kubectl rollout undo` handoff with verification commands

### `debug-pod`

Guided troubleshooting for a failing pod. References the `kubernetes` skill's `debugging.md`.

**Flow:**
1. Ask pod name/selector, namespace, cluster
2. Run diagnostic sequence: pod status, events, logs (current + previous), describe
3. Follow decision tree based on pod phase/condition
4. Check node conditions if relevant
5. Suggest fixes based on findings
6. If fix requires changes, provide handoff

### `scale-deployment`

Scale a deployment's replicas. References the `kubernetes` skill.

**Flow:**
1. Ask deployment name, namespace, cluster, target replica count
2. Check current replica count (`kubectl get deployment`)
3. Check if HPA is configured (`kubectl get hpa`)
4. If HPA exists, warn about conflict and suggest HPA adjustments instead
5. Check available node capacity (`kubectl top nodes`)
6. Provide `kubectl scale` handoff or HPA modification handoff

---

## 6. Config Extensions

### Extended `.devops.yaml` kubernetes section

```yaml
kubernetes:
  tool: kubectl                          # kubectl | oc
  gitops: argocd                         # argocd | none
  gitops_repo: harumi-k8s               # repo where K8s manifests live
  app_of_apps:
    prod: eks/bootstrap/eks-app.yaml
    dev: eks-dev/bootstrap/eks-dev-app.yaml
  clusters:
    - name: eks-prod
      context: eks-prod
      environment: production
      domain: harumi.io
      registry: 123456789.dkr.ecr.us-east-2.amazonaws.com
    - name: eks-dev
      context: eks-dev
      environment: development
      domain: dev.harumi.io
      registry: 123456789.dkr.ecr.us-east-2.amazonaws.com
  namespaces:
    - name: monitoring
      cluster: eks-prod
    - name: argocd
      cluster: eks-prod
  helm:
    default_chart_repo: https://charts.helm.sh/stable
```

### `setup-devops-config` Updates

When generating the kubernetes section, the skill will:

1. **Require cluster access** — if `kubectl` is not available or contexts are not configured, the skill will explicitly ask the user to configure access. It will state that it cannot proceed without cluster access and will not recommend generating config without it. Cluster access is mandatory to produce accurate configuration.

2. **Scan the repo** — look for ArgoCD Application YAMLs, Helm values files, Kustomize overlays, plain manifests. Detect directory structure (e.g., `eks/`, `eks-dev/` patterns). Identify app-of-apps root files.

3. **Query the cluster** — run read-only commands:
   - `kubectl config get-contexts` — discover available clusters
   - `kubectl get namespaces` — populate namespace list
   - `argocd app list` — discover existing ArgoCD applications
   - `kubectl api-resources | grep argoproj` — confirm ArgoCD CRDs
   - `helm list --all-namespaces` — discover Helm releases

4. **Cross-reference** — compare repo state with cluster state. Flag any discrepancies (apps in cluster but not in repo, or vice versa).

5. **Generate config** — produce the kubernetes section with all discovered data.

---

## 7. Bootstrap Updates

### `using-devops` SKILL.md Changes

**Add to Available Skills table:**

| Skill | Trigger | Use When |
|-------|---------|----------|
| `kubernetes` | K8s manifests, Helm, kubectl, pod issues, RBAC, network policies | Working with Kubernetes resources, debugging, manifest authoring |
| `argocd` | ArgoCD Applications, sync issues, GitOps deployment | Managing ArgoCD apps, app-of-apps, onboarding services |

**Add to Operations Commands table:**

| Command | Use When |
|---------|----------|
| `deploy-app` | Onboard a new app or service to ArgoCD |
| `create-namespace` | Create a namespace with RBAC, quotas, network policies |
| `rollback-deployment` | Roll back a deployment to a previous revision |
| `debug-pod` | Troubleshoot a failing or misbehaving pod |
| `scale-deployment` | Scale deployment replicas up or down |

**Add trigger rules** for `kubernetes`, `argocd`, and each operation command.

**Remove `kubernetes` from the "Future skills" list.**

---

## 8. Relationship to Existing Skills

- **Replaces** `harumi-k8s/.claude/skills/argocd-app/` — all ArgoCD app patterns move to the plugin's `argocd` skill with config-driven context instead of hardcoded values. The old skill in harumi-k8s should be removed once the plugin skill is validated and working.
- **Does NOT replace** `harumi-k8s/.claude/skills/grafana-dashboards/` — that will inspire the future `observability` skill
- **Complements** `infrastructure` skill — Terraform creates the EKS cluster, `kubernetes`/`argocd` skills manage what runs on it
- **Operations commands** follow the same thin-wrapper pattern as `create-iam-user`, `create-vpn-creds`, etc.
