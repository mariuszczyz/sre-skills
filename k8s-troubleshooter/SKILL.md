---
name: k8s-troubleshooter
description: Use when user needs deep-dive Kubernetes troubleshooting, root cause analysis, or investigation of specific failing resources. Provides comprehensive diagnostics for pods, nodes, deployments, services, networking (Ingress/NetworkPolicy), storage (PVC/PV), and security (RBAC). Goes beyond health monitoring to identify why things are broken.
tools: Bash, Read, Grep
---

# Kubernetes Troubleshooter Skill

A deep-diagnostics skill for root cause analysis of Kubernetes issues. Unlike the health-monitor which provides cluster-wide overviews, this skill performs targeted investigations into specific problems and correlates evidence across multiple resources to identify underlying causes.

## Overview

This skill helps you understand **why** things are broken by:

- **Deep-dive investigation** - Multi-layer analysis of failing resources
- **Root cause identification** - Correlating symptoms with underlying issues
- **Full-stack coverage** - Pods, nodes, workloads, networking, storage, security
- **Pattern recognition** - Matching symptoms to known failure patterns
- **Evidence-based recommendations** - Actionable fixes backed by diagnostic data

## When to Use This Skill

Use `/k8s-troubleshooter` when you need to:

| Scenario | Command Pattern |
|----------|-----------------|
| Specific resource is failing | `investigate <type> <name> -n <namespace>` |
| Understanding failure symptoms | `analyze failure "<symptoms description>"` |
| Finding related issues | `correlate <issue1> <issue2>` |
| Deep debugging needed | `debug <resource> -n <namespace> --deep` |

---

## Usage Patterns

### Investigate Specific Resources

```bash
# Pod investigation (full diagnostic workflow)
/k8s-troubleshooter investigate pod my-app-7d4f8c6b9-x2kp -n production

# Node deep-dive
/k8s-troubleshooter investigate node k3s-worker-1

# Deployment analysis
/k8s-troubleshooter investigate deployment api-service -n production

# Service connectivity issues
/k8s-troubleshooter investigate service backend-api -n production

# Persistent volume problems
/k8s-troubleshooter investigate pvc database-data -n production

# Ingress troubleshooting
/k8s-troubleshooter investigate ingress web-ingress -n production
```

### Analyze Failure Symptoms

```bash
/k8s-troubleshooter analyze failure "pods stuck in CrashLoopBackOff"
/k8s-troubleshooter analyze failure "service returns 503 errors intermittently"
/k8s-troubleshooter analyze failure "new deployment not receiving traffic"
/k8s-troubleshooter analyze failure "pod cannot mount volume"
```

### Correlate Multiple Issues

```bash
# Find relationship between issues
/k8s-troubleshoot correlate "high memory usage" "pod evictions"
/k8s-troubleshooter correlate "pending pods" "node pressure"
```

---

## Investigation Workflows

### 1. Pod Deep-Dive Investigation

Complete diagnostic workflow for failing pods:

```bash
# Step 1: Full pod status with all container states
kubectl get pod <pod-name> -n <namespace> -o yaml

# Step 2: Extract detailed events (scheduling + runtime)
kubectl describe pod <pod-name> -n <namespace> | tee /tmp/pod-describe.txt

# Step 3: Container state analysis
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{range .status.containerStatuses[*]}{.name}{"\t"}{.state}{"\t"}{.lastState}{"\t"}{.restartCount}{"\n"}{end}'

# Step 4: Current container logs (if running)
kubectl logs <pod-name> -n <namespace> --tail=200

# Step 5: Previous instance logs (crucial for crash analysis)
kubectl logs <pod-name> -n <namespace> --previous --tail=200

# Step 6: Multi-container pods - check all containers
kubectl logs <pod-name> -n <namespace> -c <container-name> --previous

# Step 7: Resource limits vs actual usage
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[0].resources}'

# Step 8: Volume mount status
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{range .status.volumeStatuses[*]}{.name}{"\t"}{.phase}{"\n"}{end}'

# Step 9: ServiceAccount and RBAC context
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.serviceAccountName}'
```

**Analysis Checklist:**
- [ ] Container exit code (0=success, 137=OOMKilled, 143=SIGTERM)
- [ ] LastState shows crash reason before restart
- [ ] Events show scheduling delays or runtime errors
- [ ] Logs contain stack traces or error messages
- [ ] Resource limits appropriate for workload

### 2. Node Deep-Dive Investigation

```bash
# Step 1: Full node conditions
kubectl get node <node-name> -o jsonpath='{range .status.conditions}{.type}: {.status} ({.reason}){"\n"}{end}'

# Step 2: Detailed node description
kubectl describe node <node-name> | tee /tmp/node-describe.txt

# Step 3: Capacity vs allocatable analysis
kubectl describe node <node-name> | grep -A 5 "Capacity:"
kubectl describe node <node-name> | grep -A 5 "Allocatable:"

# Step 4: Taints and tolerations affecting scheduling
kubectl get node <node-name> -o jsonpath='{.spec.taints}'

# Step 5: Pods scheduled on this node
kubectl get pods --field-selector=spec.nodeName=<node-name> -A

# Step 6: Resource usage (if metrics-server available)
kubectl top node <node-name>

# Step 7: DaemonSet pods health on node
kubectl get ds -A -o custom-columns="NAME:.metadata.name,DESIRED:.spec.replicas,CURRENT:.status.currentNumberScheduled"
```

**Key Indicators:**
- `Ready:False` with reason (KubeletNotReady, SystemOOM)
- Pressure conditions (MemoryPressure, DiskPressure, PIDPressure)
- Taints preventing pod scheduling
- Resource exhaustion patterns

### 3. Deployment Investigation

```bash
# Step 1: Rollout status and history
kubectl rollout status deployment/<deployment-name> -n <namespace> --timeout=10s || echo "Rollout not complete"
kubectl rollout history deployment/<deployment-name> -n <namespace>

# Step 2: Deployment conditions
kubectl get deployment <deployment-name> -n <namespace> -o jsonpath='{range .status.conditions}{.type}: {.status} - {.message}{"\n"}{end}'

# Step 3: ReplicaSet analysis (old vs new)
kubectl get rs -n <namespace> -l app=<app-label> -o custom-columns="NAME:.metadata.name,DESIRED:.spec.replicas,CURRENT:.status.currentReplicas,READY:.status.readyReplicas,AGE:.metadata.creationTimestamp"

# Step 4: Pod template comparison between ReplicaSets
kubectl get rs <old-rs> -n <namespace> -o yaml > /tmp/old-template.yaml
kubectl get rs <new-rs> -n <namespace> -o yaml > /tmp/new-template.yaml
diff /tmp/old-template.yaml /tmp/new-template.yaml

# Step 5: Probe configuration analysis
kubectl get deployment <deployment-name> -n <namespace> -o jsonpath='{.spec.template.spec.containers[0].livenessProbe}'
kubectl get deployment <deployment-name> -n <namespace> -o jsonpath='{.spec.template.spec.containers[0].readinessProbe}'

# Step 6: New pod events (most likely to show failure reason)
kubectl describe pod -l app=<app-label>,pod-template-hash=<new-hash> -n <namespace> | grep -A 20 "Events:"
```

### 4. Service & Network Investigation

```bash
# Step 1: Endpoint verification
kubectl get endpoints <service-name> -n <namespace>
kubectl get endpointslices -n <namespace> --filter=<service-name>

# Step 2: Selector matching analysis
echo "=== Service Selector ==="
kubectl get svc <service-name> -n <namespace> -o jsonpath='{.spec.selector}'
echo ""
echo "=== Matching Pods ==="
kubectl get pods -n <namespace> --selector=<label-selector> --show-labels

# Step 3: Port configuration verification
kubectl get svc <service-name> -n <namespace> -o yaml | grep -A 10 "ports:"
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[0].ports}'

# Step 4: NetworkPolicy analysis
kubectl get networkpolicy -n <namespace>
kubectl describe networkpolicy <policy-name> -n <namespace>

# Step 5: Ingress configuration (if applicable)
kubectl describe ingress <ingress-name> -n <namespace>
kubectl get ingressclass

# Step 6: DNS resolution test
kubectl run dns-test --rm -it --image=busybox -- nslookup <service-name>.<namespace>.svc.cluster.local || echo "DNS failed"

# Step 7: Connectivity test from within cluster
kubectl run conn-test --rm -it --image=curlimages/curl -- curl -v http://<service-name>:<port>/health || echo "Connection failed"
```

### 5. Storage Investigation (PVC/PV)

```bash
# Step 1: PVC binding status and events
kubectl describe pvc <pvc-name> -n <namespace>

# Step 2: PV details if bound
kubectl get pv <pv-name> -o yaml

# Step 3: StorageClass analysis
kubectl get storageclass
kubectl describe storageclass <storage-class-name>

# Step 4: Capacity and usage
kubectl get pvc -n <namespace> -o custom-columns="NAME:.metadata.name,CAPACITY:.spec.resources.requests.storage,ACCESS-MODES:.spec.accessModes"

# Step 5: Volume mount errors in pods
kubectl describe pod <pod-name> -n <namespace> | grep -i "volume\|mount" -A 2

# Step 6: CSI driver status (if applicable)
kubectl get csidrivers
kubectl get pods -n kube-system | grep -i csi
```

### 6. Security & RBAC Investigation

```bash
# Step 1: Identify ServiceAccount
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.serviceAccountName}'

# Step 2: RoleBindings for the ServiceAccount
kubectl get rolebindings -n <namespace> --selector="subjects[0].name=<service-account>"
kubectl get clusterrolebindings | grep <service-account>

# Step 3: Permission testing
kubectl auth can-i <verb> <resource> -n <namespace> --as=system:serviceaccount:<namespace>:<service-account>
kubectl auth can-i --list -n <namespace> --as=system:serviceaccount:<namespace>:<service-account>

# Step 4: Pod security context
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.securityContext}'
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.containers[0].securityContext}'

# Step 5: Secret/ConfigMap mount verification
kubectl get secret -n <namespace>
kubectl describe pod <pod-name> -n <namespace> | grep -A 3 "Secrets:"
```

---

## Output Format

### Root Cause Analysis Report

```markdown
## Investigation Summary

**Resource**: `production/api-server-7d4f8c6b9-x2kp` (Pod)
**Status**: CrashLoopBackOff (15 restarts in 2 hours)
**Severity**: 🔴 Critical

### Evidence Collected

| Source | Finding |
|--------|---------|
| Container State | Exit code: 137 (OOMKilled) |
| LastState | OOMKilled at 2024-03-11T14:23:45Z |
| Resource Limits | Memory limit: 256Mi, Request: 128Mi |
| Events | "Container killed due to OOM" (x15) |

### Root Cause

**Memory limit too low for application workload.**

The container is being terminated by the OOM killer because it exceeds its 256Mi memory limit. Exit code 137 confirms SIGKILL from OOM. The application likely needs at least 512Mi based on typical Java/Node.js heap requirements.

### Correlated Issues

- Same deployment shows 3 other pods in CrashLoopBackOff
- All instances have identical resource configuration
- No recent changes to memory limits (stable for 2 weeks)
- Traffic increased 40% last week (potential contributing factor)

### Recommendations

1. **Immediate**: Increase memory limit to 512Mi
   ```bash
   kubectl set resources deployment/api-server -n production --limits=memory=512Mi
   ```

2. **Short-term**: Add memory monitoring alert at 80% threshold

3. **Long-term**: Implement vertical pod autoscaler (VPA) for automatic sizing
```

---

## Read-Only Operations Only

This skill **does not** perform any of the following:
- Delete, restart, or modify resources
- Apply configuration changes
- Scale workloads
- Roll back deployments

All remediation requires explicit user action. The skill provides diagnostic information and recommendations only.

---

## Quick Reference

| Investigation Type | Key Command |
|-------------------|-------------|
| Pod crash analysis | `kubectl logs --previous` + exit code check |
| Scheduling issues | `kubectl describe pod \| grep -A 10 Events` |
| Service connectivity | Endpoint verification + selector matching |
| Storage problems | PVC/PV binding status + mount events |
| Permission errors | `kubectl auth can-i` with service account context |

---

## References

- [Diagnostic Workflows](./references/diagnostic-workflows.md) - Detailed step-by-step procedures
- [Failure Patterns](./references/failure-patterns.md) - Common issues and root causes
- [Advanced kubectl](./references/advanced-kubectl.md) - Debugging techniques
