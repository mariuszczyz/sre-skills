# kubectl Commands Reference for Kubernetes Health Monitoring

## Cluster-Level Commands

### API Server & Cluster Info
```bash
# Check cluster info and context
kubectl cluster-info
kubectl config current-context
kubectl config view --minify

# Verify API server connectivity
kubectl get --raw=/healthz
kubectl get --raw=/ready
```

### Component Status (Legacy - for reference)
```bash
# Note: Deprecated in newer clusters but still useful
kubectl component-status
```

## Node Health Commands

### Basic Node Status
```bash
# List all nodes with basic status
kubectl get nodes

# Detailed node information
kubectl get nodes -o wide
kubectl describe node <node-name>

# Node conditions (Ready, MemoryPressure, DiskPressure, PIDPressure)
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .status.conditions}{.type}:{.status}{" "}{end}{"\n"}{end}'
```

### Node Resources & Capacity
```bash
# Node capacity and allocatable resources
kubectl describe nodes | grep -A 4 "Capacity:"
kubectl describe nodes | grep -A 4 "Allocatable:"

# Check node taints (affects pod scheduling)
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{.spec.taints}{"\n"}{end}'
```

### Node Metrics (requires metrics-server)
```bash
# CPU and memory usage per node
kubectl top nodes

# Detailed resource utilization
kubectl top nodes --sort-by=cpu
kubectl top nodes --sort-by=memory
```

## Pod Health Commands

### Basic Pod Status
```bash
# List all pods across all namespaces
kubectl get pods -A

# Pods in specific namespace
kubectl get pods -n <namespace>

# Detailed pod view with restart counts and status
kubectl get pods -A -o wide
```

### Pod Status Filtering
```bash
# Non-running pods (problematic)
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded

# Pending pods (scheduling issues)
kubectl get pods -A --field-selector=status.phase==Pending

# Failed pods
kubectl get pods -A --field-selector=status.phase==Failed

# Pods with high restart counts (>3)
kubectl get pods -A -o json | jq '.items[] | select(.status.containerStatuses[].restartCount > 3) | {namespace: .metadata.namespace, name: .metadata.name, restarts: .status.containerStatuses[].restartCount}'
```

### Pod Diagnostics
```bash
# Detailed pod information including events
kubectl describe pod <pod-name> -n <namespace>

# Pod conditions and container states
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{.status.conditions}{"\n"}{.status.containerStatuses}'

# Check specific container status
kubectl get pod <pod-name> -n <namespace> -o jsonpath='{range .status.containerStatuses[*]}{.name}{" "}{.state}{"\n"}{end}'
```

### Pod Logs
```bash
# Recent logs from a container
kubectl logs <pod-name> -n <namespace>

# Logs with timestamps
kubectl logs <pod-name> -n <namespace> --timestamps

# Previous instance logs (for crashed/restarted containers)
kubectl logs <pod-name> -n <namespace> --previous

# Multi-container pod: specify container
kubectl logs <pod-name> -n <namespace> -c <container-name>

# Follow logs in real-time
kubectl logs -f <pod-name> -n <namespace>

# Last N lines of logs
kubectl logs <pod-name> -n <namespace> --tail=100
```

## Deployment & Workload Commands

### Deployments
```bash
# List all deployments
kubectl get deployments -A

# Deployment status with replica info
kubectl get deployments -A -o wide

# Detailed deployment information
kubectl describe deployment <deployment-name> -n <namespace>

# Check rollout status
kubectl rollout status deployment/<deployment-name> -n <namespace>

# Deployment conditions
kubectl get deployment <deployment-name> -n <namespace> -o jsonpath='{.status.conditions}'
```

### ReplicaSets & Pods Relationship
```bash
# List replicaset with pod counts
kubectl get rs -A

# See which pods belong to a deployment
kubectl get pods -n <namespace> -l app=<app-label>
```

### Other Workload Types
```bash
# StatefulSets
kubectl get statefulsets -A
kubectl describe statefulset <name> -n <namespace>

# DaemonSets
kubectl get daemonsets -A
kubectl describe daemonset <name> -n <namespace>

# Jobs & CronJobs
kubectl get jobs -A
kubectl get cronjobs -A
```

## Service & Network Commands

### Services
```bash
# List all services
kubectl get svc -A

# Service details including endpoints
kubectl describe svc <service-name> -n <namespace>

# Check if service has backing endpoints
kubectl get endpoints <service-name> -n <namespace>

# Endpoint slices (newer clusters)
kubectl get endpointslices -A
```

### Ingress
```bash
# List ingresses
kubectl get ingress -A

# Detailed ingress configuration
kubectl describe ingress <ingress-name> -n <namespace>
```

### Network Policies
```bash
# Check network policies (may block traffic)
kubectl get networkpolicy -A
kubectl describe networkpolicy <name> -n <namespace>
```

## Resource Monitoring Commands

### Metrics Server (if available)
```bash
# Pod resource usage
kubectl top pods -A

# Sort by CPU or memory
kubectl top pods -A --sort-by=cpu
kubectl top pods -A --sort-by=memory

# Top consumers in namespace
kubectl top pods -n <namespace> --sort-by=cpu
```

### Resource Quotas
```bash
# List resource quotas
kubectl get resourcequota -A

# Detailed quota usage
kubectl describe resourcequota <name> -n <namespace>
```

### LimitRanges
```bash
# Default resource limits
kubectl get limitrange -A
kubectl describe limitrange <name> -n <namespace>
```

## Events & Troubleshooting Commands

### Cluster Events
```bash
# Recent events across all namespaces
kubectl get events -A --sort-by='.lastTimestamp'

# Events in specific namespace (most recent)
kubectl get events -n <namespace> --sort-by='.lastTimestamp'

# Warning events only
kubectl get events -A --field-selector=type=Warning --sort-by='.lastTimestamp'

# Events for specific resource
kubectl describe pod <pod-name> -n <namespace> | grep -A 20 "Events:"
```

### Persistent Volume Issues
```bash
# PVC status
kubectl get pvc -A

# PV status and binding
kubectl get pv -A

# Detailed PVC info (includes events)
kubectl describe pvc <pvc-name> -n <namespace>
```

## JSONPath & jq for Advanced Queries

### Useful JSONPath Examples
```bash
# All pod names and statuses
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{" "}{.status.phase}{"\n"}{end}'

# Node conditions summary
kubectl get nodes -o jsonpath='{range .items[*]}{.metadata.name}{"\t"}{range .status.conditions}{.type}={.status}{" "}{end}{"\n"}{end}'

# Pod restart counts
kubectl get pods -A -o jsonpath='{range .items[*]}{.metadata.namespace}{" "}{.metadata.name}{" "}{range .status.containerStatuses[*]}{.name}={.restartCount}{" "}{end}{"\n"}{end}'
```

### jq Examples (if installed)
```bash
# Failed pods with details
kubectl get pods -A -o json | jq '.items[] | select(.status.phase == "Failed") | {namespace: .metadata.namespace, name: .metadata.name, reason: .status.reason, message: .status.message}'

# Pods not in Running state
kubectl get pods -A -o json | jq '.items[] | select(.status.phase != "Running" and .status.phase != "Succeeded") | {namespace: .metadata.namespace, name: .metadata.name, phase: .status.phase, restartCount: [.status.containerStatuses[].restartCount] | add // 0}'
```

## Quick Health Check One-Liners

```bash
# Quick cluster health summary
echo "=== Nodes ===" && kubectl get nodes --no-headers | awk '{print $2}' | sort | uniq -c && \
echo "=== Pods by Phase ===" && kubectl get pods -A --no-headers | awk '{print $3}' | sort | uniq -c

# Find unhealthy components
kubectl get nodes --field-selector=status.phase!=Ready && \
kubectl get pods -A --field-selector=status.phase!=Running,status.phase!=Succeeded

# Recent warnings
kubectl get events -A --field-selector=type=Warning --sort-by='.lastTimestamp' | head -20
```
