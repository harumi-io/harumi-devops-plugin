---
name: using-devops
description: "Bootstrap skill for harumi-devops-plugin. Injected at session start. Announces available DevOps skills, loads repo config, defines trigger rules, and enforces safety rules for infrastructure operations."
---

# DevOps Plugin

You have the **harumi-devops-plugin** installed. This plugin provides DevOps-oriented skills for infrastructure, Kubernetes, CI/CD, and cloud operations.

## Available Skills

Use the Skill tool to invoke these when triggered:

| Skill | Trigger | Use When |
|-------|---------|----------|
| `harumi-devops-plugin:infrastructure` | `.tf` files, Terraform, AWS/GCP/Azure infra | Creating, modifying, or reviewing Terraform/IaC configurations |
| `harumi-devops-plugin:setup-devops-config` | User asks to create/set up `.devops.yaml`; no config exists | Setting up the plugin for a new repo |
| `harumi-devops-plugin:kubernetes` | K8s manifests, Helm, kubectl, pod issues, RBAC | Working with Kubernetes resources, debugging, manifest authoring |
| `harumi-devops-plugin:argocd` | ArgoCD Applications, sync issues, GitOps deployment | Managing ArgoCD apps, app-of-apps, onboarding services |
| `harumi-devops-plugin:observability` | Monitoring, alerting, dashboards, PromQL/LogQL, incident investigation | Query authoring, alert rules, Grafana dashboards, active incident debugging |

## Operations Commands

Quick-action skills for daily DevOps operations. Use the Skill tool to invoke:

| Command | Use When |
|---------|----------|
| `harumi-devops-plugin:create-iam-user` | Add a new developer, admin, or contributor user |
| `harumi-devops-plugin:remove-iam-user` | Remove / offboard an IAM user |
| `harumi-devops-plugin:create-vpn-creds` | Generate VPN certificate and .ovpn config |
| `harumi-devops-plugin:revoke-vpn-creds` | Revoke a VPN certificate |
| `harumi-devops-plugin:list-vpn-users` | List active VPN certificates |
| `harumi-devops-plugin:create-service-account` | Create a new IAM service account |
| `harumi-devops-plugin:rotate-access-keys` | Rotate IAM access keys for a user/service account |
| `harumi-devops-plugin:deploy-app` | Onboard a new app or service to ArgoCD |
| `harumi-devops-plugin:create-namespace` | Create a namespace with RBAC, quotas, network policies |
| `harumi-devops-plugin:rollback-deployment` | Roll back a deployment to a previous revision |
| `harumi-devops-plugin:debug-pod` | Troubleshoot a failing or misbehaving pod |
| `harumi-devops-plugin:scale-deployment` | Scale deployment replicas up or down |

**Future skills** (not yet available):
- `cicd` — CI/CD pipeline configs, deployment workflows
- `cost-optimization` — Resource sizing, cost analysis
- `containers` — Dockerfiles, image builds, registries

## Trigger Rules

Invoke `harumi-devops-plugin:infrastructure` when you encounter ANY of:
- `.tf` files or Terraform discussions
- AWS, GCP, or Azure infrastructure tasks
- IaC changes, module creation, state management
- Infrastructure migrations or zero-downtime changes
- Cost or security review of cloud resources

Invoke `harumi-devops-plugin:setup-devops-config` when you encounter ANY of:
- User asks to create, generate, or set up `.devops.yaml`
- User says "configure the plugin" or "set up devops config"
- No `.devops.yaml` exists and the user expresses intent to configure or set up the plugin

Invoke `harumi-devops-plugin:create-iam-user` when:
- User wants to add, create, or onboard a new AWS user (developer, admin, contributor)

Invoke `harumi-devops-plugin:remove-iam-user` when:
- User wants to remove, delete, or offboard an IAM user

Invoke `harumi-devops-plugin:create-vpn-creds` when:
- User wants to create, generate, or set up VPN credentials or access

Invoke `harumi-devops-plugin:revoke-vpn-creds` when:
- User wants to revoke, remove, or disable VPN access

Invoke `harumi-devops-plugin:list-vpn-users` when:
- User wants to list VPN users, see who has VPN access, or check VPN certificates

Invoke `harumi-devops-plugin:create-service-account` when:
- User wants to create a new service account or programmatic IAM user

Invoke `harumi-devops-plugin:rotate-access-keys` when:
- User wants to rotate, renew, or replace IAM access keys

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

Invoke `harumi-devops-plugin:observability` when:
- User asks about metrics, logs, traces, alerts, or dashboards
- User mentions PromQL, LogQL, Grafana, Prometheus, Loki, Tempo
- User says "investigate", "debug", "what's wrong with", "why is X slow/down"
- User references monitoring, alerting, SLOs, SLIs, error rates

## Universal Safety Rules (NON-NEGOTIABLE)

These apply to ALL DevOps skills:

1. **Never run `terraform apply` or `terraform destroy`** — Always provide a handoff with the exact command for the user to execute
2. **Never `kubectl delete` or any write operation without explicit user confirmation** — this applies to ALL environments (production, staging, development). No exceptions.
3. **Never push images to production registries without confirmation**
4. **Always verify current state before making changes** — Use CLI commands (aws, gcloud, az, kubectl) to confirm resource existence and configuration
5. **Always present the handoff pattern for destructive actions:**

```
Configuration ready for apply!

Execute: cd [path] && terraform apply -var-file=[tfvars]
Changes: [summary]
Verification: [CLI commands to confirm]
```

## Parallel Agent Dispatch

When a user request spans multiple independent domains, dispatch agents in parallel for faster results and cleaner context isolation. Each agent runs the corresponding skill in a fresh context window.

### Agent Inventory

| Agent | Skill | Typical Use |
|-------|-------|-------------|
| `run-kubernetes` | `harumi-devops-plugin:kubernetes` | K8s investigation, manifest work |
| `run-infrastructure` | `harumi-devops-plugin:infrastructure` | Terraform state, IaC changes |
| `run-observability` | `harumi-devops-plugin:observability` | Metrics, logs, incident investigation |
| `run-argocd` | `harumi-devops-plugin:argocd` | Sync status, GitOps operations |
| `run-debug-pod` | `harumi-devops-plugin:debug-pod` | Pod troubleshooting |
| `run-deploy-app` | `harumi-devops-plugin:deploy-app` | App onboarding |

### Compatibility Matrix

| Agents | Parallel? | Notes |
|--------|-----------|-------|
| `run-infrastructure` + `run-kubernetes` | Yes | Independent targets |
| `run-kubernetes` + `run-observability` | Yes | Common in incident investigation |
| `run-infrastructure` + `run-observability` | Yes | No shared write targets |
| `run-argocd` + `run-kubernetes` | Yes | Investigation compatible |
| `run-deploy-app` + `run-debug-pod` (same app) | No | Sequence: debug first |
| Any two agents writing to the same resource | No | Always sequential |

### Dispatch Rules

When the user request maps to 2+ compatible skills:

1. **Identify** the relevant agents from the inventory
2. **Check compatibility** using the matrix — if agents are compatible, dispatch in parallel; if not, sequence them
3. **Dispatch** compatible agents simultaneously using the Agent tool, passing the specific task and context as inputs to each
4. **Collect** all results before executing any write operations
5. **Sequence writes** — execute writes one at a time, respecting declared dependencies

### Error Handling

**Parallel agent failure:**
1. Preserve and display results from successful agents
2. Name the failed agent and its error explicitly
3. Ask the user whether to proceed with partial results or abort
4. Never silently proceed into write operations with incomplete information

**Write failure:**
1. Surface the full error
2. Stop the write sequence
3. Present a manual recovery handoff command for the user to execute

**No silent retries.** All error recovery is user-gated.

## Configuration

The active `.devops.yaml` config (loaded at session start) tells you:
- **Cloud provider** — which CLI commands to use (aws, gcloud, az)
- **Terraform settings** — version, state backend, var file
- **Naming pattern** — how resources are named
- **Stack details** — K8s tool, CI/CD platform, observability stack, container runtime

Read config values to adapt your guidance to the user's specific stack.

## Relationship to Superpowers

This plugin is **domain-oriented** (how to do DevOps). Superpowers is **process-oriented** (how to work: TDD, debugging, planning). They complement each other. Use superpowers skills for workflow (brainstorming, planning, debugging) and devops skills for domain knowledge (Terraform patterns, cloud architecture, security).
