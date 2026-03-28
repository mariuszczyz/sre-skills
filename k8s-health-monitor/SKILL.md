---
name: k8s-health-monitor
description: Use when user asks to "check Kubernetes health", "monitor cluster status", "troubleshoot pods", "diagnose node issues", mentions "Kubernetes problems" or "cluster monitoring", or wants to investigate pod/node/deployment issues. Provides diagnostic workflows for K8s health assessment using kubectl commands.
tools: Bash, Read, Grep
---

# Kubernetes Health Monitor Skill

A read-only diagnostic skill for monitoring and troubleshooting Kubernetes cluster health. This skill analyzes cluster state and provides actionable insights without making changes to the cluster.

## Overview

This skill helps you diagnose Kubernetes issues by running targeted `kubectl` commands and analyzing their output. It covers:

- **Cluster overview** - API server status, context verification
- **Node health** - Node conditions, resource pressure, capacity
- **Pod diagnostics** - Status, crashes, pending pods, restart counts
- **Deployment status** - Rollout health, replica availability
- **Service/network** - Endpoints, connectivity issues
- **Resource monitoring** - CPU/memory usage (when metrics-server available)

## Prerequisites

- `kubectl` installed and configured
- Valid kubeconfig with cluster access
- Appropriate RBAC permissions for read operations

---

## GUARDRAILS — MANDATORY RULES

> **These rules apply unconditionally. No exception. No override.**

### Read-Only Enforcement

This skill operates in **strict read-only mode**. The agent MUST NOT execute any command that creates, modifies, deletes, or patches cluster resources. The following kubectl subcommands are **FORBIDDEN**:

| Forbidden subcommand | Reason |
|---|---|
| `apply`, `create`, `run` | Creates resources |
| `delete` | Destroys resources |
| `patch`, `edit`, `set` | Modifies resources |
| `scale`, `autoscale` | Alters replica state |
| `rollout restart`, `rollout undo` | Triggers restarts or rollbacks |
| `label`, `annotate`, `taint` | Mutates metadata |
| `drain`, `cordon`, `uncordon` | Alters node schedulability |
| `exec`, `cp`, `port-forward` | Interacts with running workloads |
| `replace`, `expose` | Creates or replaces resources |

Only the following read-only subcommands are permitted: `get`, `describe`, `logs`, `top`, `rollout status`, `rollout history`, `auth can-i`, `config view`, `config current-context`, `cluster-info`, and `get --raw`.

### Mandatory User Confirmation

**Every single `kubectl` command MUST be shown to the user and explicitly confirmed before execution.** The agent must:

1. State the purpose of the command in plain English
2. Display the exact command that will be run
3. Wait for the user to type "yes", "ok", "proceed", or equivalent explicit approval
4. **Never batch-execute** multiple commands without individual confirmation for each

If the user has not confirmed a command, **do not run it**.

### Prohibited Patterns

- Do NOT suggest or run `kubectl run` even with `--rm` (it creates a pod)
- Do NOT SSH into nodes or execute shell commands on cluster nodes
- Do NOT modify kubeconfig files or switch contexts without explicit user instruction
- Do NOT install any tools or agents into the cluster
- Do NOT write output to files unless the user explicitly asks for it

---

## Usage Patterns

### Quick Cluster Health Check
```
/k8s-health-monitor check cluster health
```

### Diagnose Specific Resources
```
/k8s-health-monitor diagnose pod <pod-name> -n <namespace>
/k8s-health-monitor diagnose node <node-name>
/k8s-health-monitor diagnose deployment <deployment-name> -n <namespace>
```

### Find Problematic Resources
```
/k8s-health-monitor find unhealthy pods
/k8s-health-monitor find pending pods
/k8s-health-monitor find warning events
```

---

## Diagnostic Workflows

### 1. Full Cluster Health Assessment

Run this comprehensive check to get an overview of cluster health:

```bash
# Verify cluster connectivity and context
kubectl cluster-info
kubectl config current-context

# Node status summary
kubectl get nodes -o wide

# Pod status by namespace and phase
kubectl get pods -A --no-headers | awk '{print $1, $3}' | sort | uniq -c

# Warning events (most recent)
kubectl get events -A --field-selector=type=Warning --sort-by='.lastTimestamp' | head -20

# Deployment status summary
kubectl get deployments -A -o custom-columns="NAMESPACE:.metadata.namespace,NAME:.metadata.name,DESIRED:.spec.replicas,AVAILABLE:.status.availableReplicas,READY:.status.readyReplicas"
```

### 2. Node Health Diagnostics

Check node conditions and resource pressure:

```bash
# All nodes with full details
kubectl get nodes -o wide

# Node conditions (Ready, MemoryPressure, DiskPressure, PIDPressure)
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .status.conditions}{.type}:{.status}{" "}{end}{"\n"}{end}'

# Detailed node information (includes taints, pressures, events)
kubectl describe node <node-name>

# Node resource capacity vs allocatable
kubectl describe nodes | grep -E "(Capacity|Allocatable):" -A 4

# Resource usage per node (requires metrics-server)
kubectl top nodes
```

**Key Conditions to Watch:**
- `Ready:True` - Node is healthy and accepting workloads
- `MemoryPressure:True` - Node running low on memory
- `DiskPressure:True` - Node disk space critically low
- `PIDPressure:True` - Too many processes on node

### 3. Pod Health Diagnostics

Identify and diagnose problematic pods:

```bash
# Find all non-running pods (excluding completed jobs)
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded

# Pods with high restart counts (>5)
kubectl get pods -A -o jsonpath='{range .items[?(@.status.containerStatuses[0].restartCount>5)]}{.metadata.namespace}{" "}{.metadata.name}{" "}{.status.containerStatuses[0].restartCount}{"\n"}{end}'

# Pending pods (scheduling issues)
kubectl get pods -A --field-selector=status.phase==Pending

# Detailed pod diagnostics
kubectl describe pod <pod-name> -n <namespace>

# Container logs
kubectl logs <pod-name> -n <namespace> --tail=100
kubectl logs <pod-name> -n <namespace> --previous  # For crashed containers
```

**Common Pod Issues:**
- `CrashLoopBackOff` - Container repeatedly crashing (check logs)
- `ImagePullBackOff` - Cannot pull container image
- `Pending` - Unable to schedule (resource constraints, taints)
- `OOMKilled` - Exceeded memory limit

### 4. Deployment Diagnostics

Check deployment health and rollout status:

```bash
# All deployments with replica counts
kubectl get deployments -A -o wide

# Rollout status for specific deployment
kubectl rollout status deployment/<deployment-name> -n <namespace>

# Detailed deployment info (includes events)
kubectl describe deployment <deployment-name> -n <namespace>

# ReplicaSet details
kubectl get rs -n <namespace> -o wide

# Check for failed rollouts
kubectl rollout history deployment/<deployment-name> -n <namespace>
```

### 5. Service & Network Diagnostics

Verify service connectivity and endpoints:

```bash
# List services with external IPs
kubectl get svc -A -o wide

# Check if service has backing endpoints
kubectl get endpoints <service-name> -n <namespace>

# Detailed service info (selector, ports)
kubectl describe svc <service-name> -n <namespace>

# Ingress status
kubectl get ingress -A
kubectl describe ingress <ingress-name> -n <namespace>
```

### 6. Resource Monitoring

Check resource usage and quotas:

```bash
# Pod resource usage (requires metrics-server)
kubectl top pods -A --sort-by=cpu
kubectl top pods -A --sort-by=memory

# Namespace resource quotas
kubectl get resourcequota -A
kubectl describe resourcequota <name> -n <namespace>

# Persistent volume claims status
kubectl get pvc -A
kubectl get pv -A
```

---

## Output Format

Diagnostic reports follow this structure:

### Cluster Health Summary

| Component | Status | Details |
|-----------|--------|---------|
| API Server | ✅ Healthy | Responding to requests |
| Nodes | ⚠️ 1 Warning | node-2 shows MemoryPressure |
| Pods | ❌ 3 Issues | 2 CrashLoopBackOff, 1 Pending |

### Detailed Findings

**Nodes with Issues:**
```
node-2: MemoryPressure=True - Consider removing pods or scaling up
```

**Problematic Pods:**
```
namespace/pod-name: CrashLoopBackOff (7 restarts)
  Last error: Connection refused to database
  Recommendation: Check database connectivity and connection string
```

### Recommendations

1. **Immediate**: Investigate pod crashes in production namespace
2. **Short-term**: Address memory pressure on node-2
3. **Long-term**: Consider adding node capacity for headroom

---

## Common Diagnostic Patterns

### Pattern 1: Pod Won't Start

```bash
# Step 1: Check pod status and events
kubectl describe pod <pod-name> -n <namespace>

# Step 2: Look at container state
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.status.containerStatuses[0].state}'

# Step 3: Check logs (current and previous)
kubectl logs <pod-name> -n <namespace>
kubectl logs <pod-name> -n <namespace> --previous
```

### Pattern 2: Service Not Accessible

```bash
# Step 1: Verify endpoints exist
kubectl get endpoints <service-name> -n <namespace>

# Step 2: Check pod labels match service selector
kubectl get svc <service-name> -n <namespace> -o yaml | grep -A 3 "selector:"
kubectl get pods -l app=<label> -n <namespace>

# Step 3: Verify pod readiness (endpoints only appear for Ready pods)
kubectl get pods -l app=<label> -n <namespace> -o wide

# Step 4: Check for network policies that may block traffic
kubectl get networkpolicy -n <namespace>
kubectl describe networkpolicy -n <namespace>
```

> **NOTE**: `kubectl run` is FORBIDDEN by this skill's guardrails — it creates a pod (mutative action).
> In-cluster connectivity testing requires user-initiated action outside this skill.

### Pattern 3: Deployment Not Updating

```bash
# Step 1: Check rollout status
kubectl rollout status deployment/<deployment-name> -n <namespace> --timeout=60s

# Step 2: View rollout history
kubectl rollout history deployment/<deployment-name> -n <namespace>

# Step 3: Check new pod events
kubectl describe pod -l app=<app-label> -n <namespace> | grep -A 15 "Events:"
```

---

## Read-Only Operations Only

This skill **does not** perform any of the following actions:
- Delete pods, deployments, or other resources
- Restart containers or roll back deployments
- Scale workloads up or down
- Modify configurations or apply changes
- Create ephemeral pods for connectivity testing

All remediation requires explicit user action. The skill provides diagnostic information and recommendations only.

See the **GUARDRAILS** section above for the complete mandatory rules, including the requirement for user confirmation before every command.

---

## Quick Reference Commands

| Task | Command |
|------|---------|
| Cluster overview | `kubectl get all -A` |
| Node conditions | `kubectl describe node <name>` |
| Pod events | `kubectl describe pod <name> -n <ns>` |
| Recent warnings | `kubectl get events -A --field-selector=type=Warning` |
| Resource usage | `kubectl top pods/nodes -A` |
| Deployment status | `kubectl rollout status deployment/<name>` |

---

## References

- [kubectl Commands Reference](./references/kubectl-commands.md)
- [Troubleshooting Guide](./references/troubleshooting-guide.md)
