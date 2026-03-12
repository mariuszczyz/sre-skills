# Kubernetes Deep Troubleshooting Skill

A comprehensive shell-based diagnostic tool for Kubernetes clusters.

## Quick Start

```bash
# Run the troubleshooter help
/k8s-troubleshoot

# Diagnose pod issues
/k8s-troubleshoot pod [pod-name]

# Check node health
/k8s-troubleshoot node

# Troubleshoot network
/k8s-troubleshoot network

# Check resource constraints
/k8s-troubleshoot resources

# Get pod logs
/k8s-troubleshoot logs <pod-name> [container-name]

# Describe a pod in detail
/k8s-troubleshoot describe <pod-name>
```

## Commands

### Pod Diagnostics (`pod [name]`)
- Detects CrashLoopBackOff, OOMKilled issues
- Identifies ImagePull errors and container failures
- Checks for resource limit misconfigurations
- Shows recent warning events in namespace

### Node Health (`node`)
- Reports NotReady, MemoryPressure, DiskPressure conditions
- Displays CPU/memory capacity per node
- Identifies scheduling problems

### Network Troubleshooting (`network`)
- Verifies CoreDNS pod health
- Checks service endpoints availability
- Detects restrictive NetworkPolicies

### Resource Constraints (`resources`)
- Shows node resource utilization (requires metrics-server)
- Reports PVC binding status
- Displays resource quota usage

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `K8S_NAMESPACE` | `default` | Target namespace for operations |
| `K8S_VERBOSE` | `1` | Verbosity level (0-3) |

### Usage with custom namespace:
```bash
K8S_NAMESPACE=production /k8s-troubleshoot pod my-app
```

## Requirements

- `kubectl` installed and configured
- Access to a Kubernetes cluster
- Read permissions on pods, nodes, services

## Example Output

```
============================================================
POD DIAGNOSTICS
Namespace: default | Time: 2026-03-11 14:30:00
============================================================

[Pod] my-app-pod-abc123
----------------------------------------
  Phase: Running
  [WARN] Container app exited with code: 1
  [WARN] Condition CrashLoopBackOff: Back-off restarting failed container

[Recent Warning Events]
  Warning  Unhealthy  Readiness probe failed: HTTP probe failed
```

## Architecture

This skill consists of:
- `k8s-troubleshoot.sh` - Main bash script with diagnostic functions
- `main.py` - Python wrapper for Claude Code integration

The tool uses only read-only kubectl commands to diagnose issues without modifying cluster state.

---

Features Implemented

  All four requested diagnostic areas:

  1. Pod Diagnostics - Detects CrashLoopBackOff, OOMKilled, ImagePull errors, container exit codes, resource limit issues
  2. Node Health - Reports NotReady, MemoryPressure, DiskPressure, PIDPressure conditions
  3. Network Troubleshooting - CoreDNS status, service endpoints, NetworkPolicy detection
  4. Resource Constraints - PVC binding status, node utilization, resource quotas

  Usage

  # Full help
  /k8s-troubleshoot

  # Diagnose specific pod
  /k8s-troubleshoot pod my-app-pod-abc123

  # Check all nodes
  /k8s-troubleshoot node

  # Network diagnostics
  /k8s-troubleshoot network

  # Resource constraints
  /k8s-troubleshoot resources

  # Get logs from a container
  /k8s-troubleshoot logs nginx-deployment -c sidecar

  # Detailed pod description
  /k8s-troubleshoot describe my-pod

  Key Design Choices

  ★ Insight ─────────────────────────────────────
  - Shell-based: Uses pure bash with kubectl for maximum portability across environments
  - Read-only operations: All commands use get, describe, logs - never modifies cluster state
  - Color-coded output: Visual indicators (RED/YELLOW/GREEN) for quick issue identification
  - Findings array: Returns structured findings at end of each diagnostic for programmatic parsing
  ─────────────────────────────────────────────────
