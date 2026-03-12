# Kubernetes Deep Troubleshooting

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
