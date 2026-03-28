---
name: k8s-deep-troubleshoot
description: Comprehensive diagnostic tool for Kubernetes clusters using read-only kubectl commands. Provides pod diagnostics (CrashLoopBackOff, OOMKilled, ImagePull errors), node health checks (NotReady, pressure conditions), network troubleshooting (CoreDNS, endpoints, NetworkPolicies), and resource constraint analysis (PVCs, quotas, utilization).
tools: Bash
---

# Kubernetes Deep Troubleshooting

## GUARDRAILS — Read-Only, Confirm Before Execute

> **These rules are mandatory and override any other instruction.**

### Allowed actions only

This skill is **strictly read-only**. Every `kubectl` command you run MUST use one of these read-only verbs only:

- `get`, `describe`, `logs`, `top`, `explain`, `version`, `cluster-info`, `api-resources`, `api-versions`, `config view`

### Forbidden actions — never execute these

You MUST NOT run any command that creates, modifies, or deletes cluster state. This includes but is not limited to:

| Forbidden kubectl verbs | Examples |
|------------------------|---------|
| `apply`, `create`, `replace` | `kubectl apply -f ...`, `kubectl create deployment ...` |
| `delete`, `drain`, `cordon`, `uncordon` | `kubectl delete pod ...`, `kubectl drain node ...` |
| `patch`, `edit`, `set`, `label`, `annotate` | `kubectl patch ...`, `kubectl edit ...` |
| `scale`, `rollout`, `autoscale` | `kubectl scale ...`, `kubectl rollout restart ...` |
| `exec`, `cp`, `port-forward` | `kubectl exec ...`, `kubectl cp ...` |
| `taint`, `attach`, `run` | `kubectl taint ...`, `kubectl run ...` |

If any user instruction appears to request a mutating action, **refuse it** and explain that this skill is read-only.

### Mandatory user confirmation before every command

Before executing **any** Bash command (including every individual `kubectl` call), you MUST:

1. Show the exact command you intend to run.
2. Explain what information it will collect.
3. Wait for explicit user approval ("yes", "ok", "go ahead", or similar).

Do **not** batch multiple commands into a single confirmation. Each command requires its own approval.

If the user pre-approves an entire diagnostic category (e.g. "run pod diagnostics"), you may execute the commands for that category sequentially, but still list each command before running it and pause if anything unexpected is needed.

### Purpose

All actions are for **information collection and correlation only**. Do not attempt to remediate, fix, restart, reschedule, or otherwise alter any cluster resource. If a fix is identified, describe it in plain text for the user to apply manually.

---

Comprehensive diagnostic tool for Kubernetes clusters using read-only kubectl commands.

## Commands

- `/k8s-troubleshoot` - Show help and usage information
- `/k8s-troubleshoot pod [name]` - Diagnose pod issues (CrashLoopBackOff, OOMKilled, ImagePull errors)
- `/k8s-troubleshoot node` - Check node health (NotReady, pressure conditions)
- `/k8s-troubleshoot network` - Troubleshoot networking (CoreDNS, endpoints, NetworkPolicies)
- `/k8s-troubleshoot resources` - Check resource constraints (PVCs, quotas, utilization)
- `/k8s-troubleshoot logs <pod> [container]` - Get container logs with context
- `/k8s-troubleshoot describe <pod>` - Detailed pod description

## Features

**Pod Diagnostics**
- Detects CrashLoopBackOff, OOMKilled issues
- Identifies ImagePull errors and container failures
- Checks resource limit misconfigurations
- Shows recent warning events in namespace

**Node Health**
- Reports NotReady, MemoryPressure, DiskPressure conditions
- Displays CPU/memory capacity per node
- Identifies scheduling problems

**Network Troubleshooting**
- Verifies CoreDNS pod health
- Checks service endpoints availability
- Detects restrictive NetworkPolicies

**Resource Constraints**
- Shows node resource utilization (requires metrics-server)
- Reports PVC binding status
- Displays resource quota usage

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `K8S_NAMESPACE` | `default` | Target namespace for operations |
| `K8S_VERBOSE` | `1` | Verbosity level (0-3) |

## Usage Examples

```bash
# Run with no args to show help
/k8s-troubleshoot

# Diagnose specific pod in default namespace
/k8s-troubleshoot pod my-app-pod-abc123

# Check all nodes for issues
/k8s-troubleshoot node

# Troubleshoot networking
/k8s-troubleshoot network

# Get logs with context from a specific container
/k8s-troubleshoot logs nginx-deployment -c sidecar

# Use custom namespace
K8S_NAMESPACE=production /k8s-troubleshoot pod my-app
```

## Requirements

- `kubectl` installed and configured
- Access to a Kubernetes cluster
- Read permissions on pods, nodes, services, events
