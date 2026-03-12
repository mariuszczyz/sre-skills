---
name: k8s-pv-mapper
description: Maps all Persistent Volumes (PV), Persistent Volume Claims (PVC), and their associated Pods in a Kubernetes cluster. Shows binding relationships, capacity, access modes, and volume attachment status for storage auditing and troubleshooting.
tools: Bash
---

# Kubernetes PV Mapper

A diagnostic skill for mapping Persistent Volume (PV) and Persistent Volume Claim (PVC) relationships to their consuming Pods. Provides a complete view of storage allocation and usage across the cluster.

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

## Read-Only Operations Only

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
