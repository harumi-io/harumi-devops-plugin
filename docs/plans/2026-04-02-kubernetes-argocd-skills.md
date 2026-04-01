# Kubernetes & ArgoCD Skills Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add generic, config-driven Kubernetes and ArgoCD skills to the harumi-devops-plugin, replacing the repo-specific argocd-app skill in harumi-k8s.

**Architecture:** Two domain skills (`kubernetes` for core K8s operations/manifests, `argocd` for ArgoCD-specific patterns) plus five operation commands (`deploy-app`, `create-namespace`, `rollback-deployment`, `debug-pod`, `scale-deployment`). All skills read `.devops.yaml` for repo/cluster context. The `setup-devops-config` skill is updated to scan repos and clusters for K8s config generation.

**Tech Stack:** Claude Code skills (Markdown), `.devops.yaml` (YAML config), kubectl, ArgoCD CLI, Helm

**Spec:** `docs/specs/2026-04-01-kubernetes-argocd-skills-design.md`

---

## File Structure

### New Files

```
skills/
├── kubernetes/
│   ├── SKILL.md                           # Core K8s skill
│   └── references/
│       ├── workflow.md                    # Operational phases, handoff templates
│       ├── manifests.md                   # Manifest authoring, Helm values
│       ├── security.md                    # RBAC, NetworkPolicy, pod security, secrets
│       ├── debugging.md                   # Troubleshooting decision trees
│       └── examples.md                    # Config-driven YAML snippets
├── argocd/
│   ├── SKILL.md                           # ArgoCD skill
│   └── references/
│       ├── app-patterns.md                # 3 deployment patterns
│       ├── sync-waves.md                  # Wave ordering, hooks, health checks
│       └── examples.md                    # ArgoCD Application YAMLs
├── deploy-app/SKILL.md                    # Operation: onboard app to ArgoCD
├── create-namespace/SKILL.md              # Operation: namespace + RBAC + quotas
├── rollback-deployment/SKILL.md           # Operation: rollback with safety checks
├── debug-pod/SKILL.md                     # Operation: guided pod troubleshooting
└── scale-deployment/SKILL.md              # Operation: scale with safety checks
```

### Modified Files

```
config/default.devops.yaml                 # Extended kubernetes section
skills/using-devops/SKILL.md               # Add new skills + triggers, remove from future list
skills/setup-devops-config/SKILL.md        # Add kubernetes scanning steps
.claude-plugin/plugin.json                 # Version bump
.cursor-plugin/plugin.json                 # Version bump
```

---

## Task 1: Extend Config and Setup Skill

Update the default config with richer kubernetes fields and update `setup-devops-config` to require cluster access for K8s scanning.

**Files:**
- Modify: `config/default.devops.yaml`
- Modify: `skills/setup-devops-config/SKILL.md`

- [ ] **Step 1: Update `config/default.devops.yaml`**

Replace the existing `kubernetes:` section with the extended version:

```yaml
kubernetes:
  tool: kubectl                    # kubectl | oc (openshift)
  gitops: argocd                   # argocd | none
  gitops_repo: ""                  # repo where K8s manifests live (e.g., harumi-k8s)
  app_of_apps: {}                  # root app paths per environment (e.g., prod: eks/bootstrap/eks-app.yaml)
  clusters:
    - name: eks-dev
      context: eks-dev
      environment: development
      domain: ""                   # e.g., dev.harumi.io
      registry: ""                 # e.g., 123456789.dkr.ecr.us-east-2.amazonaws.com
    - name: eks-prod
      context: eks-prod
      environment: production
      domain: ""                   # e.g., harumi.io
      registry: ""                 # e.g., 123456789.dkr.ecr.us-east-2.amazonaws.com
  namespaces: []                   # populated by setup-devops-config scanning cluster
  helm:
    default_chart_repo: ""         # e.g., https://charts.helm.sh/stable
```

- [ ] **Step 2: Update `skills/setup-devops-config/SKILL.md` detection table**

Add new detection rules to the table in Step 1:

| Field | How to detect | Default if not found |
|-------|--------------|----------------------|
| `kubernetes.gitops_repo` | Grep ArgoCD Application manifests for `repoURL` pointing to a K8s repo | ask |
| `kubernetes.app_of_apps` | Glob `**/bootstrap/*-app.yaml` with `kind: Application` | ask if argocd detected |
| `kubernetes.clusters[].environment` | Infer from directory names (`eks-dev` → development, `eks` → production) | ask |
| `kubernetes.clusters[].domain` | Grep Ingress manifests, ArgoCD apps for domain patterns | ask |
| `kubernetes.clusters[].registry` | Grep CI/CD workflows, Dockerfiles for ECR/GCR/GHCR URLs | ask |
| `kubernetes.namespaces` | **Requires cluster access** — `kubectl get namespaces` | require access |
| `kubernetes.helm.default_chart_repo` | Grep ArgoCD Application manifests for `repoURL` with `https://` chart repos | ask |

- [ ] **Step 3: Add cluster access requirement to `setup-devops-config/SKILL.md`**

Add a new section between Step 1 (Detect stack) and Step 2 (Ask about unknowns) called **"Step 1b: Verify cluster access for Kubernetes"**:

```markdown
### Step 1b: Verify cluster access for Kubernetes

If Kubernetes manifests, Helm charts, or ArgoCD Applications were detected in Step 1, cluster access is **required** to generate accurate config.

Run these read-only commands to verify access:

```bash
kubectl config get-contexts
kubectl get namespaces
```

**If kubectl is not available or contexts are not configured:**
- Tell the user: "I detected Kubernetes resources in this repo but cannot access any cluster. Cluster access is required to generate accurate kubernetes config — I need to inspect namespaces, ArgoCD apps, and Helm releases to populate the config correctly. Please configure kubectl access and run this skill again."
- **Do not proceed** with kubernetes config generation. Generate all other sections normally, but omit the kubernetes section entirely.
- Do NOT fall back to guessing or generating partial kubernetes config.

**If kubectl is available**, also run:
```bash
argocd app list --output name 2>/dev/null || echo "argocd CLI not available"
helm list --all-namespaces 2>/dev/null || echo "helm CLI not available"
```

Use the results to populate `namespaces`, cross-reference ArgoCD apps with repo manifests, and detect Helm releases.
```

- [ ] **Step 4: Update the "What NOT to do" section in `setup-devops-config/SKILL.md`**

Remove the line "Do not run CLI commands (terraform, aws, kubectl, gcloud, az, etc.) during detection" and replace with:

```markdown
- Do not run CLI commands during detection — EXCEPT for kubernetes scanning in Step 1b, where `kubectl`, `argocd`, and `helm` read-only commands are required
```

- [ ] **Step 5: Commit**

```bash
git add config/default.devops.yaml skills/setup-devops-config/SKILL.md
git commit -m "feat: extend kubernetes config and add cluster scanning to setup-devops-config"
```

---

## Task 2: Core Kubernetes Skill — SKILL.md

Create the main kubernetes skill file.

**Files:**
- Create: `skills/kubernetes/SKILL.md`

- [ ] **Step 1: Create `skills/kubernetes/SKILL.md`**

```markdown
---
name: kubernetes
description: "Work with Kubernetes resources, manifests, Helm charts, debugging, and cluster operations. Use when: (1) Creating or modifying K8s manifests (.yaml with apiVersion/kind), (2) Working with Helm charts or values files, (3) Debugging pod failures or cluster issues, (4) Configuring RBAC, NetworkPolicy, or pod security, (5) Scaling, resource limits, or HPA configuration, (6) Any kubectl-related operations."
---

# Kubernetes

Act as a **Principal Platform Engineer** for Kubernetes operations. Read the active `.devops.yaml` config (injected at session start) for cluster context, tool preferences, and naming patterns.

## Critical Rules

### 1. Inspect before acting — ALWAYS

Before creating or modifying ANY resource, check what exists in the cluster first. Never guess or assume.

```bash
# Check what exists
kubectl get <resource-type> -n <namespace> --context <context>
kubectl describe <resource-type> <name> -n <namespace> --context <context>
```

If cluster state differs from reference documentation or `.devops.yaml`, **update the references first** before proceeding.

### 2. Safety rules apply to ALL environments

These rules apply equally to production, staging, development, and any other environment. No exceptions.

- **Never** run `kubectl apply`, `kubectl delete`, `kubectl patch`, or any write operation — always provide a handoff
- **Never** run `kubectl exec` with destructive commands
- **Read-only commands are always safe**: `get`, `describe`, `logs`, `top`, `events`, `rollout status`, `rollout history`
- **Always** verify namespace and context before any write operation
- **Always** confirm the target cluster from `.devops.yaml` before running any command

### 3. Ask when ambiguous

When encountering ambiguity about namespace, cluster, resource configuration, or approach:

```
I found multiple options for [X]:
1. Option A: [describe]
2. Option B: [describe]
Which approach should I follow?
```

### 4. Update documentation after changes

After user confirms successful apply, update relevant references if the cluster state reveals patterns not yet documented.

## Handoff Pattern (NON-NEGOTIABLE)

**NEVER execute write operations.** Always provide a handoff:

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

## Workflow

1. **Consult** — Read `.devops.yaml` for cluster context, tool, naming patterns
2. **Verify** — Check current cluster state with `kubectl` read-only commands
3. **Implement** — Write/modify manifests, Helm values, RBAC configs
4. **Validate** — `kubectl apply --dry-run=client -f [file]`, schema validation
5. **Handoff** — Provide exact commands for the user to execute (NEVER apply directly)
6. **Confirm** — Provide verification commands to run after apply

See [references/workflow.md](references/workflow.md) for detailed phase instructions.

## Quick Reference

### Cluster Context

Read `.devops.yaml` kubernetes section for available clusters:

```yaml
kubernetes:
  clusters:
    - name: eks-prod
      context: eks-prod
      environment: production
    - name: eks-dev
      context: eks-dev
      environment: development
```

Always confirm which cluster the user is targeting before any operation.

### Naming

Read the `naming` section of `.devops.yaml` for the project's naming pattern. Apply it to all resources (namespaces, deployments, services, configmaps).

## Reference Documentation

Consult these based on the task:

- **[references/workflow.md](references/workflow.md)** — Detailed workflow phases, handoff templates, verification commands
- **[references/manifests.md](references/manifests.md)** — Manifest authoring patterns, Helm values best practices
- **[references/security.md](references/security.md)** — RBAC, NetworkPolicy, pod security, secrets management
- **[references/debugging.md](references/debugging.md)** — Troubleshooting decision trees for pod failures
- **[references/examples.md](references/examples.md)** — Config-driven YAML snippets
```

- [ ] **Step 2: Commit**

```bash
git add skills/kubernetes/SKILL.md
git commit -m "feat: add core kubernetes skill"
```

---

## Task 3: Kubernetes Skill — Reference Files

Create the five reference files for the kubernetes skill.

**Files:**
- Create: `skills/kubernetes/references/workflow.md`
- Create: `skills/kubernetes/references/manifests.md`
- Create: `skills/kubernetes/references/security.md`
- Create: `skills/kubernetes/references/debugging.md`
- Create: `skills/kubernetes/references/examples.md`

- [ ] **Step 1: Create `skills/kubernetes/references/workflow.md`**

```markdown
# Kubernetes Workflow and Handoff

Detailed workflow phases for Kubernetes changes. Read this when following the full change workflow.

## Phase 1: Consult Config

Read `.devops.yaml` to determine:
- Which clusters are available and their contexts
- The naming pattern for resources
- The gitops tool (argocd or none)
- The gitops repo (where manifests should live)

## Phase 2: Verify Current State

Always verify current state before changes. Never assume.

```bash
# Cluster health
kubectl cluster-info --context <context>
kubectl get nodes --context <context>

# Namespace resources
kubectl get all -n <namespace> --context <context>

# Specific resource
kubectl describe <resource-type> <name> -n <namespace> --context <context>

# Events (recent issues)
kubectl get events -n <namespace> --sort-by='.lastTimestamp' --context <context>

# Resource usage
kubectl top pods -n <namespace> --context <context>
kubectl top nodes --context <context>
```

## Phase 3: Implement

Write manifests following the project's naming conventions from `.devops.yaml`.

Key checks before writing:
- Does the namespace exist?
- Are there existing resources with similar names?
- Does the resource conflict with existing HPA, PDB, or NetworkPolicy?

## Phase 4: Validate

```bash
# Dry run against the cluster
kubectl apply --dry-run=client -f <file> --context <context>

# Server-side dry run (more thorough)
kubectl apply --dry-run=server -f <file> --context <context>

# Diff against current state
kubectl diff -f <file> --context <context>
```

## Phase 5: Handoff

Template for all mutations:

```
Configuration ready for deployment!

Please review the manifest(s), then execute:
kubectl apply -f [file] --context [context] -n [namespace]

What this will do:
- [Create/Modify/Delete] [resource count] [resource types]
- [Specific changes summary]

Verification:
kubectl get [resource] -n [namespace] --context [context]
kubectl describe [resource] [name] -n [namespace] --context [context]
kubectl rollout status deployment/[name] -n [namespace] --context [context]  # if Deployment
```

## Phase 6: Post-Apply Verification

After user confirms apply, verify:

```bash
# Check resource exists and is healthy
kubectl get <resource> <name> -n <namespace> --context <context>

# For Deployments — check rollout
kubectl rollout status deployment/<name> -n <namespace> --context <context>

# For Services — check endpoints
kubectl get endpoints <name> -n <namespace> --context <context>

# For Ingress — check address
kubectl get ingress <name> -n <namespace> --context <context>

# Check events for errors
kubectl get events -n <namespace> --sort-by='.lastTimestamp' --context <context> | head -20
```
```

- [ ] **Step 2: Create `skills/kubernetes/references/manifests.md`**

```markdown
# Manifest Authoring Patterns

Reference for writing Kubernetes manifests. Use `.devops.yaml` naming patterns for all resources.

## Deployment

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <app-name>
  namespace: <namespace>
  labels:
    app.kubernetes.io/name: <app-name>
    app.kubernetes.io/part-of: <project>
    app.kubernetes.io/managed-by: <tool>
spec:
  replicas: <count>
  strategy:
    type: RollingUpdate
    rollingUpdate:
      maxSurge: 1
      maxUnavailable: 0
  selector:
    matchLabels:
      app.kubernetes.io/name: <app-name>
  template:
    metadata:
      labels:
        app.kubernetes.io/name: <app-name>
    spec:
      containers:
        - name: <app-name>
          image: <registry>/<image>:<tag>
          ports:
            - containerPort: <port>
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
          livenessProbe:
            httpGet:
              path: /healthz
              port: <port>
            initialDelaySeconds: 15
            periodSeconds: 10
          readinessProbe:
            httpGet:
              path: /ready
              port: <port>
            initialDelaySeconds: 5
            periodSeconds: 5
      topologySpreadConstraints:
        - maxSkew: 1
          topologyKey: topology.kubernetes.io/zone
          whenUnsatisfiable: ScheduleAnyway
          labelSelector:
            matchLabels:
              app.kubernetes.io/name: <app-name>
```

## Service

```yaml
# ClusterIP (default — internal traffic)
apiVersion: v1
kind: Service
metadata:
  name: <app-name>
  namespace: <namespace>
spec:
  type: ClusterIP
  selector:
    app.kubernetes.io/name: <app-name>
  ports:
    - port: 80
      targetPort: <port>
      protocol: TCP
```

## Ingress (ALB)

```yaml
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: <app-name>
  namespace: <namespace>
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/certificate-arn: <acm-cert-arn>
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
    alb.ingress.kubernetes.io/ssl-redirect: "443"
spec:
  rules:
    - host: <app-name>.<domain>
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: <app-name>
                port:
                  number: 80
```

Use `<domain>` from `.devops.yaml` `kubernetes.clusters[].domain`.

## ConfigMap

```yaml
apiVersion: v1
kind: ConfigMap
metadata:
  name: <app-name>-config
  namespace: <namespace>
data:
  KEY: "value"
```

## PersistentVolumeClaim

```yaml
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: <app-name>-data
  namespace: <namespace>
spec:
  accessModes:
    - ReadWriteOnce
  storageClassName: gp3
  resources:
    requests:
      storage: 10Gi
```

## HorizontalPodAutoscaler

```yaml
apiVersion: autoscaling/v2
kind: HorizontalPodAutoscaler
metadata:
  name: <app-name>
  namespace: <namespace>
spec:
  scaleTargetRef:
    apiVersion: apps/v1
    kind: Deployment
    name: <app-name>
  minReplicas: 2
  maxReplicas: 10
  metrics:
    - type: Resource
      resource:
        name: cpu
        target:
          type: Utilization
          averageUtilization: 70
    - type: Resource
      resource:
        name: memory
        target:
          type: Utilization
          averageUtilization: 80
```

## PodDisruptionBudget

```yaml
apiVersion: policy/v1
kind: PodDisruptionBudget
metadata:
  name: <app-name>
  namespace: <namespace>
spec:
  minAvailable: 1
  selector:
    matchLabels:
      app.kubernetes.io/name: <app-name>
```

## Helm Values Best Practices

- Override only what differs from chart defaults — keep values files minimal
- Use `--set` for single CI-driven values (like image.tag), values files for everything else
- Pin chart versions in ArgoCD Applications or Helmfile
- Document non-obvious overrides with YAML comments
- Separate environment-specific values from shared values when managing multiple clusters
```

- [ ] **Step 3: Create `skills/kubernetes/references/security.md`**

```markdown
# Kubernetes Security Patterns

## RBAC

### Namespace-scoped Role

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: <role-name>
  namespace: <namespace>
rules:
  - apiGroups: [""]
    resources: ["pods", "services", "configmaps"]
    verbs: ["get", "list", "watch"]
  - apiGroups: ["apps"]
    resources: ["deployments"]
    verbs: ["get", "list", "watch", "update", "patch"]
```

### RoleBinding

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: <binding-name>
  namespace: <namespace>
subjects:
  - kind: ServiceAccount
    name: <sa-name>
    namespace: <namespace>
roleRef:
  kind: Role
  name: <role-name>
  apiGroup: rbac.authorization.k8s.io
```

### ClusterRole (for cross-namespace access)

```yaml
apiVersion: rbac.authorization.k8s.io/v1
kind: ClusterRole
metadata:
  name: <role-name>
rules:
  - apiGroups: [""]
    resources: ["namespaces"]
    verbs: ["get", "list", "watch"]
```

## NetworkPolicy

### Default deny all ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: <namespace>
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

### Allow specific ingress

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: allow-<source>-to-<target>
  namespace: <namespace>
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: <target-app>
  policyTypes:
    - Ingress
  ingress:
    - from:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: <source-namespace>
          podSelector:
            matchLabels:
              app.kubernetes.io/name: <source-app>
      ports:
        - port: <port>
          protocol: TCP
```

### Egress control

```yaml
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: restrict-egress
  namespace: <namespace>
spec:
  podSelector:
    matchLabels:
      app.kubernetes.io/name: <app-name>
  policyTypes:
    - Egress
  egress:
    - to:
        - namespaceSelector:
            matchLabels:
              kubernetes.io/metadata.name: kube-system
      ports:
        - port: 53
          protocol: UDP
        - port: 53
          protocol: TCP
    - to:
        - ipBlock:
            cidr: 0.0.0.0/0
            except:
              - 10.0.0.0/8
              - 172.16.0.0/12
              - 192.168.0.0/16
      ports:
        - port: 443
          protocol: TCP
```

## Pod Security Standards

### Restricted (recommended for workloads)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: <namespace>
  labels:
    pod-security.kubernetes.io/enforce: restricted
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

### Baseline (for system components that need more privileges)

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: <namespace>
  labels:
    pod-security.kubernetes.io/enforce: baseline
    pod-security.kubernetes.io/audit: restricted
    pod-security.kubernetes.io/warn: restricted
```

## Secret Management

### External Secrets Operator (preferred)

```yaml
apiVersion: external-secrets.io/v1beta1
kind: ExternalSecret
metadata:
  name: <app-name>-secrets
  namespace: <namespace>
spec:
  refreshInterval: 1h
  secretStoreRef:
    name: aws-secrets-manager
    kind: ClusterSecretStore
  target:
    name: <app-name>-secrets
    creationPolicy: Owner
  data:
    - secretKey: DATABASE_URL
      remoteRef:
        key: <secrets-path>/<app-name>
        property: database_url
```

### ServiceAccount Token

```yaml
apiVersion: v1
kind: ServiceAccount
metadata:
  name: <app-name>
  namespace: <namespace>
  annotations:
    eks.amazonaws.com/role-arn: arn:aws:iam::<account-id>:role/<role-name>
automountServiceAccountToken: false
```

Only mount tokens when the pod needs Kubernetes API access. Use IRSA (IAM Roles for Service Accounts) for AWS access.
```

- [ ] **Step 4: Create `skills/kubernetes/references/debugging.md`**

```markdown
# Kubernetes Debugging Guide

## Diagnostic Sequence

For any failing pod, run these commands in order:

```bash
# 1. Pod status overview
kubectl get pods -n <namespace> --context <context> | grep <pod-name>

# 2. Pod events
kubectl describe pod <pod-name> -n <namespace> --context <context>

# 3. Current logs
kubectl logs <pod-name> -n <namespace> --context <context> --tail=100

# 4. Previous container logs (if restarting)
kubectl logs <pod-name> -n <namespace> --context <context> --previous --tail=100

# 5. Node conditions (if pod is Pending)
kubectl describe node <node-name> --context <context>
```

## Decision Tree by Pod Phase

### Pending

Pod cannot be scheduled. Check in order:

1. **Insufficient resources**
   ```bash
   kubectl describe pod <pod-name> -n <namespace> --context <context> | grep -A5 "Events"
   kubectl top nodes --context <context>
   ```
   Look for: `Insufficient cpu`, `Insufficient memory`
   Fix: Adjust resource requests, add nodes, or use Cluster Autoscaler

2. **Node affinity/taints**
   ```bash
   kubectl get nodes --show-labels --context <context>
   kubectl describe node <node-name> --context <context> | grep -A5 "Taints"
   ```
   Fix: Adjust nodeSelector, affinity rules, or add tolerations

3. **PVC binding**
   ```bash
   kubectl get pvc -n <namespace> --context <context>
   kubectl describe pvc <pvc-name> -n <namespace> --context <context>
   ```
   Fix: Check StorageClass, available PVs, or zone constraints

### CrashLoopBackOff

Container starts but crashes repeatedly.

1. **Check logs**
   ```bash
   kubectl logs <pod-name> -n <namespace> --context <context> --previous --tail=200
   ```

2. **Check exit code**
   ```bash
   kubectl get pod <pod-name> -n <namespace> --context <context> -o jsonpath='{.status.containerStatuses[0].lastState.terminated.exitCode}'
   ```
   - Exit 1: Application error — check logs
   - Exit 137: OOMKilled — increase memory limit
   - Exit 143: SIGTERM — check preStop hooks
   - Exit 0 with restart: Check if command is wrong (one-shot vs long-running)

3. **Check resource limits**
   ```bash
   kubectl top pod <pod-name> -n <namespace> --context <context>
   kubectl describe pod <pod-name> -n <namespace> --context <context> | grep -A5 "Limits"
   ```

### ImagePullBackOff

Cannot pull container image.

1. **Check image name and tag**
   ```bash
   kubectl describe pod <pod-name> -n <namespace> --context <context> | grep "Image:"
   ```

2. **Check registry authentication**
   ```bash
   kubectl get secrets -n <namespace> --context <context> | grep regcred
   ```

3. **For ECR — check token expiry**
   ECR tokens expire every 12 hours. Node must have IAM permissions to pull.
   ```bash
   kubectl describe node <node-name> --context <context> | grep "iam"
   ```

### OOMKilled

Container exceeded memory limit.

```bash
# Check actual usage vs limits
kubectl top pod <pod-name> -n <namespace> --context <context>
kubectl describe pod <pod-name> -n <namespace> --context <context> | grep -A3 "Limits"

# Check if OOM events exist
kubectl get events -n <namespace> --context <context> --field-selector reason=OOMKilling
```

Fix: Increase memory limit, or investigate memory leak in application.

### Evicted

Node under disk or memory pressure.

```bash
kubectl describe node <node-name> --context <context> | grep -A10 "Conditions"
kubectl get events --context <context> --field-selector reason=Evicted
```

Fix: Clean up disk, adjust eviction thresholds, or add nodes.

### Terminating (stuck)

Pod won't terminate.

```bash
# Check for finalizers
kubectl get pod <pod-name> -n <namespace> --context <context> -o jsonpath='{.metadata.finalizers}'

# Check if node is healthy
kubectl get node <node-name> --context <context>
```

If stuck due to finalizers, provide handoff to user:
```
kubectl patch pod <pod-name> -n <namespace> --context <context> -p '{"metadata":{"finalizers":null}}' --type merge
```

Only suggest force delete as last resort:
```
kubectl delete pod <pod-name> -n <namespace> --context <context> --force --grace-period=0
```
```

- [ ] **Step 5: Create `skills/kubernetes/references/examples.md`**

```markdown
# Kubernetes YAML Examples

Config-driven examples using `.devops.yaml` values. Replace placeholders with actual config values.

## Placeholder Reference

| Placeholder | Source in `.devops.yaml` |
|-------------|------------------------|
| `<namespace>` | `naming.namespace` |
| `<stage>` | `naming.stage` |
| `<naming-pattern>` | `naming.pattern` |
| `<context>` | `kubernetes.clusters[].context` |
| `<domain>` | `kubernetes.clusters[].domain` |
| `<registry>` | `kubernetes.clusters[].registry` |

## Complete Application Stack

A minimal but production-ready app deployment:

### Namespace + NetworkPolicy

```yaml
apiVersion: v1
kind: Namespace
metadata:
  name: <app-namespace>
  labels:
    pod-security.kubernetes.io/enforce: restricted
---
apiVersion: networking.k8s.io/v1
kind: NetworkPolicy
metadata:
  name: default-deny-ingress
  namespace: <app-namespace>
spec:
  podSelector: {}
  policyTypes:
    - Ingress
```

### Deployment + Service + Ingress

```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: <app-name>
  namespace: <app-namespace>
spec:
  replicas: 2
  selector:
    matchLabels:
      app.kubernetes.io/name: <app-name>
  template:
    metadata:
      labels:
        app.kubernetes.io/name: <app-name>
    spec:
      serviceAccountName: <app-name>
      containers:
        - name: <app-name>
          image: <registry>/<app-name>:<tag>
          ports:
            - containerPort: 8080
          resources:
            requests:
              cpu: "100m"
              memory: "128Mi"
            limits:
              cpu: "500m"
              memory: "512Mi"
          livenessProbe:
            httpGet:
              path: /healthz
              port: 8080
            initialDelaySeconds: 15
          readinessProbe:
            httpGet:
              path: /ready
              port: 8080
            initialDelaySeconds: 5
---
apiVersion: v1
kind: Service
metadata:
  name: <app-name>
  namespace: <app-namespace>
spec:
  selector:
    app.kubernetes.io/name: <app-name>
  ports:
    - port: 80
      targetPort: 8080
---
apiVersion: networking.k8s.io/v1
kind: Ingress
metadata:
  name: <app-name>
  namespace: <app-namespace>
  annotations:
    kubernetes.io/ingress.class: alb
    alb.ingress.kubernetes.io/scheme: internet-facing
    alb.ingress.kubernetes.io/target-type: ip
    alb.ingress.kubernetes.io/listen-ports: '[{"HTTPS":443}]'
spec:
  rules:
    - host: <app-name>.<domain>
      http:
        paths:
          - path: /
            pathType: Prefix
            backend:
              service:
                name: <app-name>
                port:
                  number: 80
```

## ResourceQuota for Namespace

```yaml
apiVersion: v1
kind: ResourceQuota
metadata:
  name: default-quota
  namespace: <app-namespace>
spec:
  hard:
    requests.cpu: "4"
    requests.memory: 8Gi
    limits.cpu: "8"
    limits.memory: 16Gi
    pods: "20"
    services: "10"
    persistentvolumeclaims: "5"
```

## LimitRange for Namespace

```yaml
apiVersion: v1
kind: LimitRange
metadata:
  name: default-limits
  namespace: <app-namespace>
spec:
  limits:
    - default:
        cpu: "500m"
        memory: "512Mi"
      defaultRequest:
        cpu: "100m"
        memory: "128Mi"
      type: Container
```

## Verification Commands

After applying any manifest, verify with:

```bash
# Resource created/updated
kubectl get <resource> -n <namespace> --context <context>

# No error events
kubectl get events -n <namespace> --sort-by='.lastTimestamp' --context <context> | head -10

# Pods running (for workloads)
kubectl get pods -n <namespace> --context <context>

# Endpoints populated (for services)
kubectl get endpoints -n <namespace> --context <context>
```
```

- [ ] **Step 6: Commit**

```bash
git add skills/kubernetes/
git commit -m "feat: add kubernetes skill with reference documentation"
```

---

## Task 4: ArgoCD Skill — SKILL.md

Create the ArgoCD skill main file.

**Files:**
- Create: `skills/argocd/SKILL.md`

- [ ] **Step 1: Create `skills/argocd/SKILL.md`**

```markdown
---
name: argocd
description: "Manage ArgoCD applications, app-of-apps patterns, sync waves, and GitOps deployments. Use when: (1) Creating or modifying ArgoCD Application manifests, (2) Onboarding apps or services to ArgoCD, (3) Troubleshooting sync/drift issues, (4) Working with app-of-apps patterns, (5) Managing sync waves and deployment ordering."
---

# ArgoCD

Act as a **Principal Platform Engineer** for ArgoCD and GitOps operations. Read the active `.devops.yaml` config (injected at session start) for cluster context, gitops repo, and app-of-apps structure.

## Critical Rules

### 1. Inspect before acting — ALWAYS

Before creating any ArgoCD Application, check what already exists:

```bash
# List all ArgoCD apps
argocd app list

# Check specific app
argocd app get <app-name>

# Check if namespace exists
kubectl get namespace <namespace> --context <context>

# Check for existing Helm releases
helm list -n <namespace> --context <context>
```

If cluster state differs from reference documentation or `.devops.yaml`, **update the references first**.

### 2. Safety rules apply to ALL environments

- **Never** run `argocd app sync`, `argocd app delete`, or `argocd app patch` — always provide a handoff
- **Never** run `kubectl apply` for ArgoCD Application manifests — always provide a handoff
- **Read-only commands are always safe**: `argocd app list`, `argocd app get`, `argocd app diff`, `argocd app history`
- **Always** verify app health and sync status before and after changes

### 3. Ask when ambiguous

When encountering ambiguity about deployment pattern, target cluster, sync wave, or namespace:

```
I found multiple options for [X]:
1. Option A: [describe]
2. Option B: [describe]
Which approach should I follow?
```

### 4. Update documentation after changes

After user confirms successful deployment, update relevant references if the cluster state reveals patterns not yet documented.

## Handoff Pattern (NON-NEGOTIABLE)

**NEVER execute ArgoCD mutations.** Always provide a handoff:

```
ArgoCD Application ready for deployment!

Please review the manifest(s), then execute:
kubectl apply -f [file] --context [context]

What this will do:
- [summary: new app, new component, adopted release, etc.]

Verification:
argocd app get <app-name>
kubectl get pods -n <namespace> --context <context>
```

## Deployment Patterns

Three patterns for deploying applications via ArgoCD:

### 1. Application Deployment

New app with its own repo, CI/CD pipeline, and container image. Use when deploying a custom application.

### 2. Cluster Service

Off-the-shelf Helm chart deployed as cluster infrastructure. Uses two-source pattern (Helm chart + values from gitops repo). Use for monitoring stacks, ingress controllers, cert-manager, etc.

### 3. Helm Adoption

Onboard an existing Helm release already running in the cluster into ArgoCD management. Use when migrating from manual Helm to GitOps.

See [references/app-patterns.md](references/app-patterns.md) for detailed steps for each pattern.

## Config Reference

```yaml
# From .devops.yaml
kubernetes:
  gitops: argocd
  gitops_repo: harumi-k8s           # where manifests live
  app_of_apps:
    prod: eks/bootstrap/eks-app.yaml
    dev: eks-dev/bootstrap/eks-dev-app.yaml
  clusters:
    - name: eks-prod
      context: eks-prod
      environment: production
      domain: harumi.io
      registry: <ecr-url>
```

Always read these values to determine target paths, domains, and registry URLs.

## Reference Documentation

Consult these based on the task:

- **[references/app-patterns.md](references/app-patterns.md)** — Detailed steps for each deployment pattern
- **[references/sync-waves.md](references/sync-waves.md)** — Wave ordering, hooks, health checks, retry policies
- **[references/examples.md](references/examples.md)** — ArgoCD Application YAML examples
```

- [ ] **Step 2: Commit**

```bash
git add skills/argocd/SKILL.md
git commit -m "feat: add argocd skill"
```

---

## Task 5: ArgoCD Skill — Reference Files

Create the three reference files for the ArgoCD skill.

**Files:**
- Create: `skills/argocd/references/app-patterns.md`
- Create: `skills/argocd/references/sync-waves.md`
- Create: `skills/argocd/references/examples.md`

- [ ] **Step 1: Create `skills/argocd/references/app-patterns.md`**

```markdown
# ArgoCD Deployment Patterns

Three patterns for deploying applications. All patterns are config-driven — read `.devops.yaml` for cluster details, domains, registries, and gitops repo path.

## Placeholders

All templates use these placeholders. Replace with values from `.devops.yaml`:

| Placeholder | Source |
|-------------|--------|
| `<cluster-dir>` | Infer from target cluster (e.g., `eks` for prod, `eks-dev` for dev) |
| `<environment>` | `kubernetes.clusters[].environment` |
| `<domain>` | `kubernetes.clusters[].domain` |
| `<registry>` | `kubernetes.clusters[].registry` |
| `<gitops-repo>` | `kubernetes.gitops_repo` |
| `<namespace>` | Derived from naming pattern |

## Pattern 1: Application Deployment

For new applications with their own GitHub repository and CI-driven image builds.

### Before Starting

```bash
# Check existing ArgoCD apps
argocd app list

# Check if namespace exists
kubectl get namespace <app-namespace> --context <context>

# Check ECR for existing repo
aws ecr describe-repositories --repository-names <app-name> 2>/dev/null
```

### Directory Structure in Gitops Repo

```
<cluster-dir>/argocd/
└── <app-name>-app.yaml              # ArgoCD Application
```

The app itself lives in its own repo with:
```
<app-repo>/
├── .github/workflows/ci.yaml        # Build + push to ECR + update image tag
├── deploy/
│   ├── namespace.yaml
│   ├── deployment.yaml
│   ├── service.yaml
│   ├── ingress.yaml
│   ├── configmap.yaml
│   └── externalsecret.yaml           # If secrets needed
├── Dockerfile
└── src/
```

### Steps

1. Inspect existing apps and namespaces in the cluster
2. Create the app repository structure (Dockerfile, manifests, CI workflow)
3. Create ArgoCD Application manifest in the gitops repo
4. If ECR is needed, provide Terraform handoff for ECR repository creation
5. Provide handoff for applying the ArgoCD Application

### Handoff

```
Application '<app-name>' manifests ready!

1. Push app repo:
   cd <app-repo> && git add . && git commit -m "feat: initial setup" && git push

2. (If ECR needed) Apply Terraform:
   cd core-infrastructure && terraform apply -var-file=<environment>.tfvars

3. Deploy ArgoCD Application:
   kubectl apply -f <cluster-dir>/argocd/<app-name>-app.yaml --context <context>

Verification:
   argocd app get <app-name>
   kubectl get pods -n <app-namespace> --context <context>
```

---

## Pattern 2: Cluster Service

For Helm chart-based infrastructure services using the App-of-Apps pattern.

### Before Starting

```bash
# Check existing Helm releases in target namespace
helm list -n <namespace> --context <context>

# Check if chart is available
helm search repo <chart-name> --version <chart-version>

# Check for CRD conflicts
kubectl get crd --context <context> | grep <related-crds>
```

### Directory Structure in Gitops Repo

For a new stack (group of related services):
```
<cluster-dir>/<stack-name>/
├── argocd/
│   ├── <stack-name>-app.yaml         # Parent app (App-of-Apps)
│   ├── resources-app.yaml            # Supporting resources (wave 0)
│   ├── <component-a>-app.yaml        # Helm component (wave 1+)
│   └── <component-b>-app.yaml        # Helm component (wave 1+)
├── resources/
│   ├── namespace.yaml
│   ├── secrets.yaml
│   └── configmaps/
├── <component-a>-values.yaml
└── <component-b>-values.yaml
```

For adding a component to an existing stack:
```
<cluster-dir>/<stack-name>/
├── argocd/
│   └── <new-component>-app.yaml      # New Helm component
└── <new-component>-values.yaml       # New values file
```

### Key Conventions

- **Two-source pattern**: Helm chart source + gitops repo as `$values` ref
- **Parent app excludes itself**: `directory.exclude` prevents circular references
- **Resources app creates namespace**: Only wave 0 uses `CreateNamespace=true`
- **ServerSideApply**: Use for charts with CRDs or large resources
- **RespectIgnoreDifferences**: Use for resources with auto-populated fields (e.g., webhook caBundle)

### Steps

1. Inspect existing apps, Helm releases, and CRDs in the cluster
2. Determine if this is a new stack or adding to an existing one
3. Create parent app (if new stack) or just the component app
4. Create Helm values file with minimal overrides
5. Create supporting resources (namespace, secrets) if needed
6. Set sync wave ordering based on dependencies
7. Provide handoff

---

## Pattern 3: Helm Adoption

For onboarding an existing Helm release into ArgoCD management.

### Before Starting

```bash
# Get current release info
helm list -n <namespace> --context <context>
helm get values <release-name> -n <namespace> --context <context> -o yaml

# Check for manual modifications
helm get manifest <release-name> -n <namespace> --context <context> > /tmp/helm-manifest.yaml
kubectl diff -f /tmp/helm-manifest.yaml --context <context>
```

### Directory Structure in Gitops Repo

```
<cluster-dir>/
├── argocd/
│   ├── <app-name>-app.yaml              # ArgoCD Application
│   └── <app-name>-resources-app.yaml    # Optional: supporting resources
└── <app-name>/
    ├── helm-values.yaml                  # Extracted from running release
    └── resources/                         # Optional: ingress, configmaps
```

### Steps

1. Inspect the running Helm release (values, manifest, version)
2. Check for manual modifications outside Helm
3. Export current values to a values file
4. Create ArgoCD Application manifest with `helm.releaseName` matching the existing release name
5. Use `ServerSideApply` to handle ownership conflicts
6. Verify sync shows no drift before proceeding
7. Provide handoff

### Critical: releaseName Must Match

The `helm.releaseName` in the ArgoCD Application MUST match the existing Helm release name. If they don't match, ArgoCD will create a NEW release instead of adopting the existing one, causing duplicate resources.
```

- [ ] **Step 2: Create `skills/argocd/references/sync-waves.md`**

```markdown
# ArgoCD Sync Waves and Ordering

## Wave Ordering Conventions

| Wave | Purpose | Examples |
|------|---------|---------|
| 0 | Supporting resources (namespace, secrets, configmaps) | `resources-app.yaml` |
| 1 | Independent backends (no inter-dependencies) | `loki-app.yaml`, `tempo-app.yaml`, `redis-app.yaml` |
| 2 | Services depending on wave 1 | `prometheus-stack-app.yaml` (needs loki endpoint) |
| 3+ | Services depending on earlier waves | `otel-collector-app.yaml` (needs prom + loki + tempo) |

Set wave with annotation:
```yaml
metadata:
  annotations:
    argocd.argoproj.io/sync-wave: "1"
```

## Sync Hooks

```yaml
metadata:
  annotations:
    argocd.argoproj.io/hook: PreSync    # Runs before sync
    # Options: PreSync, Sync, PostSync, SyncFail, Skip
    argocd.argoproj.io/hook-delete-policy: HookSucceeded
    # Options: HookSucceeded, HookFailed, BeforeHookCreation
```

Common uses:
- **PreSync**: Database migrations, config validation
- **PostSync**: Smoke tests, notification
- **SyncFail**: Alerting, cleanup

## Health Checks

ArgoCD has built-in health checks for common resources. Custom health checks can be defined in ArgoCD ConfigMap:

```yaml
# In argocd-cm ConfigMap
resource.customizations.health.<group_kind>: |
  hs = {}
  if obj.status ~= nil then
    if obj.status.conditions ~= nil then
      for i, condition in ipairs(obj.status.conditions) do
        if condition.type == "Ready" and condition.status == "True" then
          hs.status = "Healthy"
          hs.message = condition.message
          return hs
        end
      end
    end
  end
  hs.status = "Progressing"
  hs.message = "Waiting for Ready condition"
  return hs
```

## Retry Policy

```yaml
spec:
  syncPolicy:
    retry:
      limit: 5
      backoff:
        duration: 5s
        factor: 2
        maxDuration: 3m
```

## ServerSideApply

Use for:
- Helm charts that install CRDs
- Resources with many fields (>256KB)
- Resources managed by multiple controllers

```yaml
spec:
  syncPolicy:
    syncOptions:
      - ServerSideApply=true
```

## RespectIgnoreDifferences

Use for fields auto-populated by webhooks or controllers:

```yaml
spec:
  ignoreDifferences:
    - group: admissionregistration.k8s.io
      kind: MutatingWebhookConfiguration
      jsonPointers:
        - /webhooks/0/clientConfig/caBundle
  syncPolicy:
    syncOptions:
      - RespectIgnoreDifferences=true
```

## App-of-Apps Pattern

Parent app auto-discovers child apps in its `argocd/` directory:

```yaml
spec:
  source:
    repoURL: <gitops-repo-url>
    path: <cluster-dir>/<stack-name>/argocd
    targetRevision: HEAD
    directory:
      recurse: false
      exclude: '<stack-name>-app.yaml'  # Exclude self to prevent circular reference
```

The `exclude` is critical — without it, the parent app will try to manage itself.
```

- [ ] **Step 3: Create `skills/argocd/references/examples.md`**

```markdown
# ArgoCD Application YAML Examples

Config-driven examples. Replace placeholders with values from `.devops.yaml`.

## Application Deployment (Pattern 1)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <app-name>
  namespace: argocd
  labels:
    app.kubernetes.io/part-of: <project>
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/<org>/<app-name>.git
    targetRevision: HEAD
    path: deploy
  destination:
    server: https://kubernetes.default.svc
    namespace: <app-namespace>
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## Cluster Service — Parent App (Pattern 2)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <stack-name>
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "0"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/<org>/<gitops-repo>.git
    targetRevision: HEAD
    path: <cluster-dir>/<stack-name>/argocd
    directory:
      recurse: false
      exclude: '<stack-name>-app.yaml'
  destination:
    server: https://kubernetes.default.svc
    namespace: argocd
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
```

## Cluster Service — Helm Component (Pattern 2)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <component-name>
  namespace: argocd
  labels:
    app.kubernetes.io/part-of: <stack-name>
  annotations:
    argocd.argoproj.io/sync-wave: "<wave>"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  sources:
    - repoURL: <chart-repo-url>
      chart: <chart-name>
      targetRevision: <chart-version>
      helm:
        releaseName: <component-name>
        valueFiles:
          - $values/<cluster-dir>/<stack-name>/<component-name>-values.yaml
    - repoURL: https://github.com/<org>/<gitops-repo>.git
      targetRevision: HEAD
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: <namespace>
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=false
      - ServerSideApply=true
```

## Cluster Service — Resources App (Pattern 2, Wave 0)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <stack-name>-resources
  namespace: argocd
  labels:
    app.kubernetes.io/part-of: <stack-name>
  annotations:
    argocd.argoproj.io/sync-wave: "0"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  source:
    repoURL: https://github.com/<org>/<gitops-repo>.git
    targetRevision: HEAD
    path: <cluster-dir>/<stack-name>/resources
  destination:
    server: https://kubernetes.default.svc
    namespace: <namespace>
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - CreateNamespace=true
```

## Helm Adoption (Pattern 3)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: Application
metadata:
  name: <app-name>
  namespace: argocd
  annotations:
    argocd.argoproj.io/sync-wave: "<wave>"
  finalizers:
    - resources-finalizer.argocd.argoproj.io
spec:
  project: default
  sources:
    - repoURL: <chart-repo-url>
      chart: <chart-name>
      targetRevision: <chart-version>
      helm:
        releaseName: <existing-release-name>   # MUST match existing release
        valueFiles:
          - $values/<cluster-dir>/<app-name>/helm-values.yaml
    - repoURL: https://github.com/<org>/<gitops-repo>.git
      targetRevision: HEAD
      ref: values
  destination:
    server: https://kubernetes.default.svc
    namespace: <namespace>
  syncPolicy:
    automated:
      prune: true
      selfHeal: true
    syncOptions:
      - ServerSideApply=true
```

## AppProject (for namespace isolation)

```yaml
apiVersion: argoproj.io/v1alpha1
kind: AppProject
metadata:
  name: <project-name>
  namespace: argocd
spec:
  description: <project-description>
  sourceRepos:
    - https://github.com/<org>/<gitops-repo>.git
    - <chart-repo-url>
  destinations:
    - namespace: <namespace>
      server: https://kubernetes.default.svc
  clusterResourceWhitelist:
    - group: ''
      kind: Namespace
  namespaceResourceBlacklist:
    - group: ''
      kind: ResourceQuota
```
```

- [ ] **Step 4: Commit**

```bash
git add skills/argocd/
git commit -m "feat: add argocd skill with reference documentation"
```

---

## Task 6: Operation Command — deploy-app

**Files:**
- Create: `skills/deploy-app/SKILL.md`

- [ ] **Step 1: Create `skills/deploy-app/SKILL.md`**

```markdown
---
name: deploy-app
description: "Onboard a new application or service to ArgoCD. Supports three deployment patterns: application deployment, cluster service, and helm adoption. Use when: user wants to deploy, onboard, or add an app to ArgoCD."
---

# Deploy App

Onboard a new application to ArgoCD management.

## Inputs

Ask for these if not provided:

1. **App name** (e.g., "my-api")
2. **Deployment pattern**:
   - **Application deployment** — new app with its own repo, CI/CD, container image
   - **Cluster service** — off-the-shelf Helm chart (monitoring, ingress, etc.)
   - **Helm adoption** — onboard an existing Helm release to ArgoCD
3. **Target cluster** — from `.devops.yaml` `kubernetes.clusters[]` list

## Execution Steps

Follow these steps exactly. Do not skip or reorder.

### Step 1: Read config

Read `.devops.yaml` for:
- `kubernetes.gitops_repo` — where to create ArgoCD manifests
- `kubernetes.clusters[]` — target cluster context, domain, registry
- `kubernetes.app_of_apps` — root app paths
- `naming` — resource naming pattern

### Step 2: Inspect cluster state

```bash
# Existing ArgoCD apps
argocd app list

# Existing namespaces
kubectl get namespaces --context <context>

# Existing Helm releases (for adoption pattern)
helm list --all-namespaces --context <context>
```

If the app already exists in ArgoCD, report the conflict and ask the user how to proceed.

### Step 3: Follow the deployment pattern

Invoke the `argocd` skill and follow the appropriate pattern from `references/app-patterns.md`:

- **Application deployment**: Generate app repo structure + ArgoCD Application in gitops repo
- **Cluster service**: Generate ArgoCD Application(s) + Helm values in gitops repo
- **Helm adoption**: Export existing values + generate ArgoCD Application in gitops repo

### Step 4: Hand off

Provide the exact commands needed to deploy. Format depends on pattern — see `argocd` skill's app-patterns reference for handoff templates.

Remind the user to verify after apply:
```bash
argocd app get <app-name>
kubectl get pods -n <app-namespace> --context <context>
```
```

- [ ] **Step 2: Commit**

```bash
git add skills/deploy-app/SKILL.md
git commit -m "feat: add deploy-app operation command"
```

---

## Task 7: Operation Command — create-namespace

**Files:**
- Create: `skills/create-namespace/SKILL.md`

- [ ] **Step 1: Create `skills/create-namespace/SKILL.md`**

```markdown
---
name: create-namespace
description: "Create a Kubernetes namespace with RBAC, quotas, network policies, and optional ArgoCD registration. Use when: user wants to create a new namespace."
---

# Create Namespace

Create a namespace with associated security and resource controls.

## Inputs

Ask for these if not provided:

1. **Namespace name** (e.g., "my-app")
2. **Target cluster** — from `.devops.yaml` `kubernetes.clusters[]` list
3. **Resource quotas** — ask if custom limits are needed, otherwise use defaults

## Execution Steps

### Step 1: Check if namespace exists

```bash
kubectl get namespace <namespace-name> --context <context>
kubectl get namespaces --context <context>
```

If namespace already exists, report it and ask the user how to proceed.

### Step 2: Generate namespace resources

Create the following manifests:

1. **Namespace** with pod security labels
2. **ResourceQuota** with sensible defaults (4 CPU, 8Gi memory, 20 pods)
3. **LimitRange** with default container limits
4. **NetworkPolicy** — default deny ingress
5. **RBAC RoleBinding** — if the user specifies who should have access

Use patterns from the `kubernetes` skill's `references/security.md` and `references/examples.md`.

### Step 3: Register in ArgoCD (if configured)

If `.devops.yaml` has `kubernetes.gitops: argocd`:
- Create an ArgoCD Application manifest for the namespace resources
- Place it in the gitops repo's `<cluster-dir>/argocd/` directory
- Use patterns from the `argocd` skill's `references/examples.md`

### Step 4: Hand off

```
Namespace '<namespace-name>' resources ready!

Execute:
kubectl apply -f <namespace-manifest-path> --context <context>

What this will do:
- Create namespace <namespace-name>
- Set ResourceQuota (CPU: 4, Memory: 8Gi, Pods: 20)
- Set LimitRange (default: 500m CPU, 512Mi memory)
- Apply default-deny NetworkPolicy
- [RBAC if configured]

Verification:
kubectl get namespace <namespace-name> --context <context>
kubectl get resourcequota -n <namespace-name> --context <context>
kubectl get networkpolicy -n <namespace-name> --context <context>
```
```

- [ ] **Step 2: Commit**

```bash
git add skills/create-namespace/SKILL.md
git commit -m "feat: add create-namespace operation command"
```

---

## Task 8: Operation Command — rollback-deployment

**Files:**
- Create: `skills/rollback-deployment/SKILL.md`

- [ ] **Step 1: Create `skills/rollback-deployment/SKILL.md`**

```markdown
---
name: rollback-deployment
description: "Roll back a Kubernetes deployment to a previous revision with safety checks. Use when: user wants to rollback, revert, or undo a deployment."
---

# Rollback Deployment

Roll back a deployment to a previous revision.

## Inputs

Ask for these if not provided:

1. **Deployment name** (e.g., "my-api")
2. **Namespace**
3. **Target cluster** — from `.devops.yaml` `kubernetes.clusters[]` list
4. **Target revision** — optional, defaults to previous revision

## Execution Steps

### Step 1: Inspect current state

```bash
# Current rollout status
kubectl rollout status deployment/<deployment-name> -n <namespace> --context <context>

# Current replica set
kubectl get replicaset -n <namespace> --context <context> -l app.kubernetes.io/name=<deployment-name>

# Revision history
kubectl rollout history deployment/<deployment-name> -n <namespace> --context <context>
```

### Step 2: Show revision details

If the user hasn't specified a target revision, show the last 5 revisions with their details:

```bash
kubectl rollout history deployment/<deployment-name> -n <namespace> --context <context> --revision=<N>
```

Ask the user which revision to roll back to.

### Step 3: Show what will change

```bash
# Compare current vs target revision
kubectl rollout history deployment/<deployment-name> -n <namespace> --context <context> --revision=<current>
kubectl rollout history deployment/<deployment-name> -n <namespace> --context <context> --revision=<target>
```

Present a clear diff of what changes (image tag, env vars, resource limits, etc.).

### Step 4: Hand off

```
Rollback ready!

Execute:
kubectl rollout undo deployment/<deployment-name> -n <namespace> --context <context> --to-revision=<target>

What this will do:
- Roll back <deployment-name> from revision <current> to revision <target>
- [Specific changes: image tag, env vars, etc.]

Verification:
kubectl rollout status deployment/<deployment-name> -n <namespace> --context <context>
kubectl get pods -n <namespace> --context <context> -l app.kubernetes.io/name=<deployment-name>
```
```

- [ ] **Step 2: Commit**

```bash
git add skills/rollback-deployment/SKILL.md
git commit -m "feat: add rollback-deployment operation command"
```

---

## Task 9: Operation Command — debug-pod

**Files:**
- Create: `skills/debug-pod/SKILL.md`

- [ ] **Step 1: Create `skills/debug-pod/SKILL.md`**

```markdown
---
name: debug-pod
description: "Guided troubleshooting for a failing or misbehaving Kubernetes pod. Runs diagnostic sequence and follows decision trees. Use when: user wants to debug, troubleshoot, or investigate a pod issue."
---

# Debug Pod

Guided troubleshooting for a failing pod.

## Inputs

Ask for these if not provided:

1. **Pod name or selector** (e.g., "my-api-7d9f8b6c5-x2k4j" or "app=my-api")
2. **Namespace**
3. **Target cluster** — from `.devops.yaml` `kubernetes.clusters[]` list

## Execution Steps

### Step 1: Run diagnostic sequence

Run these commands in order and analyze the output:

```bash
# 1. Pod status
kubectl get pods -n <namespace> --context <context> | grep <pod-name-or-selector>

# 2. Detailed pod description (events, conditions, container status)
kubectl describe pod <pod-name> -n <namespace> --context <context>

# 3. Current container logs
kubectl logs <pod-name> -n <namespace> --context <context> --tail=100

# 4. Previous container logs (if pod is restarting)
kubectl logs <pod-name> -n <namespace> --context <context> --previous --tail=100

# 5. Recent events in namespace
kubectl get events -n <namespace> --sort-by='.lastTimestamp' --context <context> | head -20
```

### Step 2: Follow decision tree

Based on the pod phase/condition, follow the appropriate troubleshooting path from the `kubernetes` skill's `references/debugging.md`:

- **Pending** → check node capacity, affinity/taints, PVC binding
- **CrashLoopBackOff** → check logs, exit codes, resource limits
- **ImagePullBackOff** → check image name, registry auth, ECR tokens
- **OOMKilled** → check memory limits vs actual usage
- **Evicted** → check node conditions, disk pressure
- **Terminating (stuck)** → check finalizers, node health

### Step 3: Check node conditions (if relevant)

If the issue appears node-related:

```bash
kubectl describe node <node-name> --context <context>
kubectl top nodes --context <context>
```

### Step 4: Suggest fixes

Based on findings, suggest specific fixes. If fixes require manifest changes, write the changes and provide a handoff. Never apply fixes directly.
```

- [ ] **Step 2: Commit**

```bash
git add skills/debug-pod/SKILL.md
git commit -m "feat: add debug-pod operation command"
```

---

## Task 10: Operation Command — scale-deployment

**Files:**
- Create: `skills/scale-deployment/SKILL.md`

- [ ] **Step 1: Create `skills/scale-deployment/SKILL.md`**

```markdown
---
name: scale-deployment
description: "Scale a Kubernetes deployment's replicas with safety checks for HPA conflicts and node capacity. Use when: user wants to scale up, scale down, or change replica count."
---

# Scale Deployment

Scale a deployment's replica count with safety checks.

## Inputs

Ask for these if not provided:

1. **Deployment name** (e.g., "my-api")
2. **Namespace**
3. **Target cluster** — from `.devops.yaml` `kubernetes.clusters[]` list
4. **Target replica count**

## Execution Steps

### Step 1: Inspect current state

```bash
# Current deployment state
kubectl get deployment <deployment-name> -n <namespace> --context <context>

# Check if HPA exists
kubectl get hpa -n <namespace> --context <context> | grep <deployment-name>

# Current pod distribution
kubectl get pods -n <namespace> --context <context> -l app.kubernetes.io/name=<deployment-name> -o wide

# Available node capacity
kubectl top nodes --context <context>
```

### Step 2: Check for HPA conflict

If an HPA is configured for this deployment:

```bash
kubectl describe hpa <hpa-name> -n <namespace> --context <context>
```

**Warn the user:**
```
⚠ An HPA is managing this deployment (min: X, max: Y, current: Z).
Manual scaling will be overridden by the HPA on the next evaluation cycle.

To change the scale permanently, modify the HPA instead:
kubectl patch hpa <hpa-name> -n <namespace> --context <context> -p '{"spec":{"minReplicas":<new-min>,"maxReplicas":<new-max>}}'

To scale temporarily (will revert), use the handoff below.
```

Ask the user how to proceed.

### Step 3: Check capacity (if scaling up)

If scaling up, verify node capacity:

```bash
kubectl top nodes --context <context>
kubectl describe nodes --context <context> | grep -A5 "Allocated resources"
```

If insufficient capacity, warn the user and suggest enabling Cluster Autoscaler or adding nodes first.

### Step 4: Hand off

```
Scale ready!

Execute:
kubectl scale deployment/<deployment-name> -n <namespace> --context <context> --replicas=<target>

What this will do:
- Change replicas from <current> to <target>
- [HPA warning if applicable]

Verification:
kubectl get deployment <deployment-name> -n <namespace> --context <context>
kubectl get pods -n <namespace> --context <context> -l app.kubernetes.io/name=<deployment-name>
kubectl rollout status deployment/<deployment-name> -n <namespace> --context <context>
```
```

- [ ] **Step 2: Commit**

```bash
git add skills/scale-deployment/SKILL.md
git commit -m "feat: add scale-deployment operation command"
```

---

## Task 11: Update Bootstrap Skill

Update `using-devops` to register all new skills and operation commands.

**Files:**
- Modify: `skills/using-devops/SKILL.md`

- [ ] **Step 1: Add kubernetes and argocd to Available Skills table**

In the `## Available Skills` table, add two rows:

```markdown
| `harumi-devops-plugin:kubernetes` | K8s manifests, Helm, kubectl, pod issues, RBAC | Working with Kubernetes resources, debugging, manifest authoring |
| `harumi-devops-plugin:argocd` | ArgoCD Applications, sync issues, GitOps deployment | Managing ArgoCD apps, app-of-apps, onboarding services |
```

- [ ] **Step 2: Add operation commands to Operations Commands table**

In the `## Operations Commands` table, add five rows:

```markdown
| `harumi-devops-plugin:deploy-app` | Onboard a new app or service to ArgoCD |
| `harumi-devops-plugin:create-namespace` | Create a namespace with RBAC, quotas, network policies |
| `harumi-devops-plugin:rollback-deployment` | Roll back a deployment to a previous revision |
| `harumi-devops-plugin:debug-pod` | Troubleshoot a failing or misbehaving pod |
| `harumi-devops-plugin:scale-deployment` | Scale deployment replicas up or down |
```

- [ ] **Step 3: Add trigger rules**

Add trigger rules after the existing ones:

```markdown
Invoke `harumi-devops-plugin:kubernetes` when you encounter ANY of:
- K8s manifests (`.yaml` files with `apiVersion` and `kind`)
- Helm charts, Helm values files, or Helm operations
- kubectl operations or discussions
- Pod failures, debugging, or troubleshooting
- RBAC, NetworkPolicy, or pod security configuration
- Resource limits, scaling, or HPA discussions

Invoke `harumi-devops-plugin:argocd` when you encounter ANY of:
- ArgoCD Application manifests or discussions
- Sync/drift issues or ArgoCD troubleshooting
- App-of-apps patterns or GitOps deployment
- Onboarding services to ArgoCD management

Invoke `harumi-devops-plugin:deploy-app` when:
- User wants to deploy, onboard, or add an app to ArgoCD

Invoke `harumi-devops-plugin:create-namespace` when:
- User wants to create a new Kubernetes namespace

Invoke `harumi-devops-plugin:rollback-deployment` when:
- User wants to rollback, revert, or undo a deployment

Invoke `harumi-devops-plugin:debug-pod` when:
- User wants to debug, troubleshoot, or investigate a pod issue

Invoke `harumi-devops-plugin:scale-deployment` when:
- User wants to scale up, scale down, or change replica count of a deployment
```

- [ ] **Step 4: Update Future Skills list**

Remove `kubernetes` from the "Future skills" list. Update to:

```markdown
**Future skills** (not yet available):
- `cicd` — CI/CD pipeline configs, deployment workflows
- `cost-optimization` — Resource sizing, cost analysis
- `observability` — Monitoring, alerting, dashboards
- `containers` — Dockerfiles, image builds, registries
```

- [ ] **Step 5: Update safety rules**

In the `## Universal Safety Rules` section, update rule 2 to apply to all environments:

```markdown
2. **Never `kubectl delete` or any write operation without explicit user confirmation** — this applies to ALL environments (production, staging, development). No exceptions.
```

- [ ] **Step 6: Commit**

```bash
git add skills/using-devops/SKILL.md
git commit -m "feat: register kubernetes and argocd skills in bootstrap"
```

---

## Task 12: Update Plugin Manifests and Version Bump

**Files:**
- Modify: `.claude-plugin/plugin.json`
- Modify: `.cursor-plugin/plugin.json`

- [ ] **Step 1: Bump version in `.claude-plugin/plugin.json`**

Change `"version": "0.2.0"` to `"version": "0.5.0"` (major feature addition: kubernetes + argocd).

- [ ] **Step 2: Bump version in `.cursor-plugin/plugin.json`**

Change `"version": "0.2.0"` to `"version": "0.5.0"`.

- [ ] **Step 3: Commit**

```bash
git add .claude-plugin/plugin.json .cursor-plugin/plugin.json
git commit -m "chore: bump version to 0.5.0 for kubernetes and argocd skills"
```

---
