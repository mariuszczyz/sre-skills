# Kubernetes Troubleshooting Guide

## Common Issues and Diagnostic Approaches

### Pod Issues

#### CrashLoopBackOff
**Symptoms**: Pod repeatedly crashes and restarts

**Diagnostic Steps**:
```bash
# Check pod status and restart count
kubectl get pod <pod-name> -n <namespace>

# View container logs (current instance)
kubectl logs <pod-name> -n <namespace>

# View previous instance logs (often contains crash reason)
kubectl logs <pod-name> -n <namespace> --previous

# Check pod events for scheduling/runtime issues
kubectl describe pod <pod-name> -n <namespace> | grep -A 20 "Events:"
```

**Common Causes**:
- Application crashes due to code errors or missing dependencies
- Liveness probe failures (app temporarily slow but not dead)
- Missing environment variables or configuration
- Permission issues with volumes/secrets
- Out of memory (OOMKilled)

#### ImagePullBackOff / ErrImagePull
**Symptoms**: Pod cannot pull container image

**Diagnostic Steps**:
```bash
# Check pod events for specific error message
kubectl describe pod <pod-name> -n <namespace> | grep -i "image"

# Verify image exists (manual check)
docker pull <image-name>  # or crane/crane CLI tools
```

**Common Causes**:
- Typo in image name or tag
- Image doesn't exist in registry
- Registry authentication issues (missing/invalid imagePullSecrets)
- Network connectivity to registry blocked
- Private registry without proper credentials

#### Pending Pods
**Symptoms**: Pod stuck in Pending state, not scheduled

**Diagnostic Steps**:
```bash
# Check why pod is pending
kubectl describe pod <pod-name> -n <namespace> | grep -A 10 "Events:"

# Check node capacity and taints
kubectl get nodes -o wide
kubectl describe node <node-name> | grep -A 5 "Taints"

# Check resource quotas
kubectl describe quota -n <namespace>

# Check if pods are pending due to resource constraints
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.status.allocatable.cpu}{"\t"}{.status.allocatable.memory}{"\n"}{end}'
```

**Common Causes**:
- Insufficient resources (CPU/memory) on available nodes
- Node taints without matching tolerations
- Pod affinity/anti-affinity rules cannot be satisfied
- Resource quota exceeded in namespace
- PersistentVolume claims cannot be bound

#### OOMKilled
**Symptoms**: Container killed due to memory limits

**Diagnostic Steps**:
```bash
# Check container status for OOM
kubectl describe pod <pod-name> -n <namespace> | grep -i "oom"

# Check last state shows OOMKilled
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.status.containerStatuses[0].lastState}'

# View resource limits
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 5 "resources:"
```

**Common Causes**:
- Memory limit too low for application needs
- Memory leak in application
- Sudden traffic spike causing memory surge

### Node Issues

#### Node NotReady
**Symptoms**: Node shows NotReady status

**Diagnostic Steps**:
```bash
# Check node conditions
kubectl describe node <node-name> | grep -A 10 "Conditions:"

# Check kubelet status (requires SSH to node)
systemctl status kubelet  # on the node itself

# Check system resources on node
free -h  # memory
df -h    # disk space
```

**Common Causes**:
- Kubelet crashed or not running
- Node out of memory (OOM)
- Disk pressure (filesystem full)
- PID pressure (too many processes)
- Network connectivity issues to API server
- Container runtime not available

#### MemoryPressure / DiskPressure / PIDPressure
**Symptoms**: Node shows pressure conditions

**Diagnostic Steps**:
```bash
# Check all node conditions
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{range .status.conditions}{.type}: {.status}{"\n"}{end}{end}'

# Describe specific node for details
kubectl describe node <node-name>
```

**Remediation**:
- **MemoryPressure**: Remove pods, increase node memory, investigate memory leaks
- **DiskPressure**: Clean up unused images/containers, expand disk, remove old logs
- **PIDPressure**: Investigate fork bombs, increase system PID limits

### Deployment Issues

#### Rollout Stuck / Failed
**Symptoms**: Deployment not completing update

**Diagnostic Steps**:
```bash
# Check rollout status with details
kubectl rollout status deployment/<deployment-name> -n <namespace>

# Check deployment events
kubectl describe deployment <deployment-name> -n <namespace> | grep -A 20 "Events:"

# Check ReplicaSet status
kubectl get rs -n <namespace> -o wide

# Check pod events for new pods
kubectl describe pod -l app=<app-label> -n <namespace>
```

**Common Causes**:
- New image fails health checks (readiness/liveness probes)
- Configuration error in new version
- Insufficient resources for new replicas
- Pod disruption budgets blocking update

#### Replica Count Mismatch
**Symptoms**: Desired replicas != Available replicas

**Diagnostic Steps**:
```bash
# Check deployment status
kubectl get deployment <deployment-name> -n <namespace> -o wide

# See why pods aren't starting
kubectl get pods -l app=<app-label> -n <namespace>
kubectl describe pod -l app=<app-label> -n <namespace>
```

### Service & Network Issues

#### Service Not Routing Traffic
**Symptoms**: Cannot reach service endpoint

**Diagnostic Steps**:
```bash
# Check if endpoints exist
kubectl get endpoints <service-name> -n <namespace>

# Verify pod labels match service selector
kubectl get svc <service-name> -n <namespace> -o yaml | grep -A 5 "selector:"
kubectl get pods -n <namespace> --show-labels | grep <pod-name>

# Test connectivity from within cluster
kubectl run test --rm -it --image=curlimages/curl -- curl <service-name>:<port>
```

**Common Causes**:
- No pods match service selector labels
- Pod readiness probes failing (pods not ready)
- Network policies blocking traffic
- Service port mismatch with container port

#### Ingress Issues
**Symptoms**: External traffic not reaching services via ingress

**Diagnostic Steps**:
```bash
# Check ingress status and backend
kubectl describe ingress <ingress-name> -n <namespace>

# Verify ingress controller is running
kubectl get pods -n <ingress-namespace> | grep -i ingress

# Check ingress class matches controller
kubectl get ingressclass
```

### Persistent Volume Issues

#### PVC Pending / NotBound
**Symptoms**: PersistentVolumeClaim stuck in Pending

**Diagnostic Steps**:
```bash
# Check PVC events
kubectl describe pvc <pvc-name> -n <namespace> | grep -A 20 "Events:"

# Check available PVs
kubectl get pv

# Verify storage class exists
kubectl get storageclass
```

**Common Causes**:
- No matching PersistentVolume available
- StorageClass not configured correctly
- Insufficient storage capacity
- Access mode mismatch (ReadWriteOnce vs ReadWriteMany)

#### Volume Mount Failures
**Symptoms**: Pod fails to start due to volume issues

**Diagnostic Steps**:
```bash
# Check pod events for volume errors
kubectl describe pod <pod-name> -n <namespace> | grep -i "volume"

# Verify PVC is bound
kubectl get pvc <pvc-name> -n <namespace>
```

## Resource & Performance Issues

### High CPU/Memory Usage
**Diagnostic Steps**:
```bash
# Check resource usage (requires metrics-server)
kubectl top pods -A --sort-by=cpu
kubectl top pods -A --sort-by=memory
kubectl top nodes

# Identify resource-intensive containers
kubectl get pods -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,CPU:.status.containerStatuses[0].resources.requests.cpu,MEMORY:.status.containerStatuses[0].resources.requests.memory
```

### Throttling Issues
**Symptoms**: Application slow or unresponsive under load

**Diagnostic Steps**:
```bash
# Check if containers have resource limits set
kubectl get pod <pod-name> -n <namespace> -o yaml | grep -A 10 "resources:"

# Monitor for OOM kills
kubectl describe pod <pod-name> -n <namespace> | grep -i "oom"
```

## Security & Access Issues

#### Permission Denied / RBAC Issues
**Symptoms**: ServiceAccount lacks permissions

**Diagnostic Steps**:
```bash
# Check pod's service account
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.spec.serviceAccountName}'

# Check Role/ClusterRole bindings
kubectl get rolebindings -n <namespace>
kubectl get clusterrolebindings

# Test permissions (as admin)
kubectl auth can-i <verb> <resource> -n <namespace>
```

## Quick Diagnostic Commands

### Full Cluster Health Check
```bash
#!/bin/bash
echo "=== CLUSTER HEALTH SUMMARY ==="
echo ""
echo "--- Nodes ---"
kubectl get nodes
echo ""
echo "--- Pods by Namespace & Status ---"
kubectl get pods -A --no-headers | awk '{print $1, $3}' | sort | uniq -c
echo ""
echo "--- Warning Events (Last 10) ---"
kubectl get events -A --field-selector=type=Warning --sort-by='.lastTimestamp' | head -15
echo ""
echo "--- Deployments Status ---"
kubectl get deployments -A -o custom-columns=NAMESPACE:.metadata.namespace,NAME:.metadata.name,DESIRED:.spec.replicas,AVAILABLE:.status.availableReplicas
```

### Pod-Specific Deep Dive
```bash
#!/bin/bash
POD=$1
NS=${2:-default}
echo "=== POD: $POD/$NS ==="
kubectl get pod $POD -n $NS
echo ""
echo "--- Container Status ---"
kubectl get pod $POD -n $NS -o jsonpath='{range .status.containerStatuses[*]}{.name}: {.state} (restarts: {.restartCount}){"\n"}{end}'
echo ""
echo "--- Recent Logs ---"
kubectl logs $POD -n $NS --tail=50
echo ""
echo "--- Events ---"
kubectl describe pod $POD -n $NS | grep -A 15 "Events:"
```

## Best Practices

### Monitoring Setup Recommendations
1. **Enable metrics-server** for resource monitoring via `kubectl top`
2. **Set up Prometheus/Grafana** for historical metrics and alerting
3. **Configure log aggregation** (EFK stack, Loki, etc.) for centralized logging
4. **Use PodDisruptionBudgets** to maintain availability during maintenance

### Proactive Health Checks
- Regularly review warning events: `kubectl get events -A --field-selector=type=Warning`
- Monitor pod restart counts: High restarts indicate instability
- Check for pending pods regularly
- Review node conditions and resource pressure states
