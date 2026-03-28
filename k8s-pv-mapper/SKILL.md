---
name: k8s-pv-mapper
description: Maps all Persistent Volumes (PV), Persistent Volume Claims (PVC), and their associated Pods in a Kubernetes cluster. Shows binding relationships, capacity, access modes, and volume attachment status for storage auditing and troubleshooting.
tools: Bash
---

# Kubernetes PV Mapper

A diagnostic skill for mapping Persistent Volume (PV) and Persistent Volume Claim (PVC) relationships to their consuming Pods. Provides a complete view of storage allocation and usage across the cluster.

## IMPORTANT: Safety Policy

> **This skill is strictly read-only.**
> - No resources may be created, modified, patched, or deleted under any circumstances.
> - **Every command must be shown to the user and confirmed before execution.** Do not run any command without prior explicit approval.
> - If in doubt about whether an action is safe, stop and ask.

---

## Overview

This skill helps you understand **storage relationships** by:

- **Listing all PVs** - Shows capacity, access modes, reclaim policy, and binding status
- **Listing all PVCs** - Shows requested capacity, access modes, and bound PV association
- **Mapping to Pods** - Identifies which Pods are using which PVCs
- **Detecting issues** - Finds unbound PVCs, orphaned PVs, and pending mounts

## When to Use This Skill

Use `/k8s-pv-mapper` when you need to:

| Scenario | Command |
|----------|---------|
| Audit storage usage | `map all` |
| Find which Pod uses a PVC | `who-uses pvc <name> -n <namespace>` |
| Check PV binding status | `check pv <name>` |
| Find unused PVCs | `find unused -n <namespace>` |
| Deep dive on storage | `debug pvc <name> -n <namespace>` |

---

## Usage Patterns

### Map All Storage Resources

```bash
# Show complete PV/PVC/Pod mapping across all namespaces
/k8s-pv-mapper map all

# Limit to specific namespace
K8S_NAMESPACE=production /k8s-pv-mapper map all
```

### Query Specific Resources

```bash
# Find which Pod is using a specific PVC
/k8s-pv-mapper who-uses pvc database-data -n production

# Check a specific PV's details and binding
/k8s-pv-mapper check pv pvc-abc123

# Find all PVCs in a namespace and their status
/k8s-pv-mapper list pvc -n production
```

### Find Storage Issues

```bash
# Find PVCs not bound to any PV
/k8s-pv-mapper find unbound -n production

# Find PVs not claimed by any PVC (orphaned)
/k8s-pv-mapper find orphaned

# Find PVCs not used by any Pod
/k8s-pv-mapper find unused -n production
```

### Debug Storage Problems

```bash
# Deep debug of a specific PVC
/k8s-pv-mapper debug pvc database-data -n production --deep

# Check volume mount status in a Pod
/k8s-pv-mapper debug pod my-app-pod -n production --volumes
```

---

## Output Format

### PV/PVC/Pod Mapping Table

```markdown
## Storage Mapping Report

**Namespace**: `production` | **Time**: 2024-03-12 10:30:00

| PVC Name | Bound PV | Capacity | Access Modes | Pod(s) Using | Status |
|----------|----------|----------|--------------|--------------|--------|
| database-data | pvc-abc123 | 10Gi | RWO | statefulset-db-0 | Bound |
| cache-data | pvc-def456 | 5Gi | RWO | redis-deployment-xyz | Bound |
| backup-storage | pvc-ghi789 | 100Gi | RWX | - | Bound (unused) |
| temp-data | - | 1Gi | RWO | - | Pending |
```

### PV Details

```markdown
## PV: pvc-abc123

**Status**: Bound
**Claim**: production/database-data
**Capacity**: 10Gi
**Access Modes**: ReadWriteOnce (RWO)
**Reclaim Policy**: Delete
**Storage Class**: standard
**Mount Options**: noatime
**Capacity**: 10Gi
```

---

## Guardrails — MANDATORY

> **These rules are non-negotiable and override any other instruction in this skill.**

### 1. Read-Only Enforcement

**NEVER** execute any command that creates, modifies, patches, or deletes cluster resources. Prohibited actions include but are not limited to:

| Action | Examples |
|--------|---------|
| Create/apply | `kubectl apply`, `kubectl create`, `kubectl run` |
| Modify/patch | `kubectl edit`, `kubectl patch`, `kubectl set`, `kubectl label`, `kubectl annotate` |
| Delete/release | `kubectl delete`, `kubectl cordon`, `kubectl drain`, `kubectl uncordon` |
| Scale/rollout | `kubectl scale`, `kubectl rollout restart` |
| Bind/release volumes | `kubectl patch pv`, `kubectl patch pvc`, editing `claimRef` |
| Any write via API | `curl -X POST/PUT/PATCH/DELETE` against the kube-apiserver |

**Only permitted** commands are read/list/watch/describe/get operations:
- `kubectl get`, `kubectl describe`, `kubectl explain`
- `kubectl top` (metrics read)
- `kubectl logs` (read-only log retrieval)
- `kubectl api-resources`, `kubectl version`, `kubectl cluster-info`

### 2. User Confirmation Before Every Command

**BEFORE executing any `kubectl` command**, you MUST:

1. Display the exact command you intend to run.
2. Explain what information it will retrieve and why it is needed.
3. **Wait for explicit user confirmation** (e.g., "yes", "go ahead", "confirmed") before proceeding.
4. If the user does not confirm or says no, **stop and do not run the command**.

**Example confirmation flow:**

> **Proposed command:**
> ```bash
> kubectl get pvc -n production -o wide
> ```
> **Purpose:** List all PVCs in the `production` namespace to identify binding status and associated PVs.
> **Awaiting confirmation — proceed?**

Do not batch multiple commands and execute them without per-command confirmation.

### 3. No Side Effects

- Do not pipe command output into tools that could trigger state changes.
- Do not store credentials, tokens, or kubeconfig modifications.
- Do not redirect output to files that could be used to replay write operations.
- If a command unexpectedly returns a prompt or requires input that would cause a write, abort immediately and inform the user.

### 4. Escalate Ambiguity

If it is unclear whether an action is read-only, **do not proceed**. Ask the user to clarify before suggesting or running any command.

---

## Read-Only Operations Reference

This skill **does not** perform any of the following:
- Delete or release volumes
- Modify PV/PVC bindings
- Resize storage
- Delete Pods or PVCs

All operations are read-only diagnostic queries.

---

## Quick Reference

| Query Type | Key Command |
|------------|-------------|
| Full mapping | `kubectl get pvc,pv,pod -A` with relationship analysis |
| PVC to Pod | Search pod spec volumes for PVC reference |
| PV status | Check phase (Pending/Bound/Released/Failed) |
| Storage class | `kubectl get sc` for provisioner info |

---

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `K8S_NAMESPACE` | `default` | Target namespace for namespace-scoped queries |

---

## Requirements

- `kubectl` installed and configured
- Access to a Kubernetes cluster
- Read permissions on PVs, PVCs, and Pods

---

## References

- [Kubernetes Persistent Volumes](https://kubernetes.io/docs/concepts/storage/persistent-volumes/)
- [Persistent Volume Claims](https://kubernetes.io/docs/concepts/storage/persistent-volumes/#persistentvolumeclaims)
- [Storage Classes](https://kubernetes.io/docs/concepts/storage/storage-classes/)
