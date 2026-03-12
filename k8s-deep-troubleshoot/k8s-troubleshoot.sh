#!/bin/bash
# =============================================================================
# Kubernetes Deep Troubleshooting Tool
# =============================================================================
# A comprehensive shell-based diagnostic tool for K8s clusters.
# Supports pod diagnostics, node health checks, network troubleshooting,
# and resource constraint analysis.
#
# Usage: k8s-troubleshoot <command> [options]
# Commands:
#   pod [name]     - Diagnose pod issues (with optional specific pod name)
#   node           - Check node health and conditions
#   network        - Troubleshoot network connectivity
#   resources      - Check resource constraints and quotas
#   logs <pod>     - Get recent logs from a pod
#   describe <pod> - Detailed pod description
# =============================================================================

set -euo pipefail

# Configuration
NAMESPACE="${K8S_NAMESPACE:-default}"
VERBOSE="${K8S_VERBOSE:-1}"  # 0=silent, 1=basic, 2=detailed, 3=debug

# Colors for output
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $*"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $*"; }
log_error() { echo -e "${RED}[ERROR]${NC} $*" >&2; }
log_success() { echo -e "${GREEN}[OK]${NC} $*"; }

# Check kubectl availability
check_kubectl() {
    if ! command -v kubectl &>/dev/null; then
        log_error "kubectl not found. Please install Kubernetes CLI."
        exit 1
    fi

    # Verify cluster connectivity
    if ! kubectl cluster-info &>/dev/null; then
        log_error "Cannot connect to Kubernetes cluster."
        log_info "Verify your kubeconfig is configured correctly."
        exit 1
    fi
}

# Get timestamp for logging
timestamp() {
    date '+%Y-%m-%d %H:%M:%S'
}

# =============================================================================
# POD DIAGNOSTICS
# =============================================================================
diagnose_pod_issues() {
    local pod_name="${1:-}"
    local findings=()

    echo "============================================================"
    echo "POD DIAGNOSTICS"
    echo "Namespace: $NAMESPACE | Time: $(timestamp)"
    echo "============================================================"

    # Get list of pods if no specific name provided
    if [[ -z "$pod_name" ]]; then
        log_info "Scanning all pods in namespace..."
        pod_name=$(kubectl get pods -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || echo "")

        if [[ -z "$pod_name" ]]; then
            log_warn "No pods found in namespace $NAMESPACE"
            return 0
        fi
    fi

    # Process each pod
    for pod in $pod_name; do
        echo -e "\n${BLUE}[Pod]${NC} $pod"
        echo "----------------------------------------"

        # Get pod status
        local phase=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")
        echo -e "  Phase: ${GREEN}$phase${NC}"

        # Check for failed conditions
        local conditions=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.status.conditions[*].type}' 2>/dev/null)
        for cond in $conditions; do
            local status=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath="{.status.conditions[?(@.type=='$cond')].status}" 2>/dev/null)

            if [[ "$status" != "True" ]]; then
                local reason=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath="{.status.conditions[?(@.type=='$cond')].reason}" 2>/dev/null || echo "")
                local message=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath="{.status.conditions[?(@.type=='$cond')].message}" 2>/dev/null || echo "")

                if [[ "$reason" =~ ^(CrashLoopBackOff|Error|Failed|Unschedulable)$ ]]; then
                    log_warn "Condition $cond: $reason - ${message:0:80}"
                    findings+=("pod:$pod:condition:$cond")
                fi
            fi
        done

        # Check container states for issues
        local containers=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[*].name}' 2>/dev/null)

        for container in $containers; do
            # Check for OOMKilled
            local terminated_reason=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath="{.status.containerStatuses[?(@.name=='$container')].lastState.terminated.reason}" 2>/dev/null || echo "")

            if [[ "$terminated_reason" == "OOMKilled" ]]; then
                log_warn "Container $container: OOMKilled - Consider increasing memory limits"
                findings+=("pod:$pod:container:$container:issue:OOMKilled")
            fi

            # Check for waiting states (ImagePullBackOff, etc.)
            local wait_reason=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath="{.status.containerStatuses[?(@.name=='$container')].state.waiting.reason}" 2>/dev/null || echo "")

            if [[ "$wait_reason" =~ ^(ImagePullBackOff|ErrImagePull)$ ]]; then
                local wait_msg=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath="{.status.containerStatuses[?(@.name=='$container')].state.waiting.message}" 2>/dev/null || echo "")
                log_warn "Container $container waiting: $wait_reason ${wait_msg:0:60}"
                findings+=("pod:$pod:container:$container:issue:ImagePullError")
            fi

            # Check for crash loop exit codes
            local exit_code=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath="{.status.containerStatuses[?(@.name=='$container')].lastState.terminated.exitCode}" 2>/dev/null || echo "")

            if [[ -n "$exit_code" && "$exit_code" != "0" ]]; then
                log_warn "Container $container exited with code: $exit_code"
                findings+=("pod:$pod:container:$container:issue:CrashLoop")
            fi
        done

        # Check resource limits
        local has_limits=$(kubectl get pod "$pod" -n "$NAMESPACE" -o jsonpath='{.spec.containers[*].resources.limits}' 2>/dev/null || echo "")

        if [[ -z "$has_limits" ]]; then
            log_warn "Pod $pod has no resource limits defined (recommended for production)"
        fi
    done

    # Get recent warning events
    echo -e "\n${BLUE}[Recent Warning Events]${NC}"
    local events=$(kubectl get events -n "$NAMESPACE" --sort-by='.lastTimestamp' 2>/dev/null | grep -E "(FailedScheduling|FailedMount|Unhealthy|BackOff|Killing|Failed)" || true)

    if [[ -n "$events" ]]; then
        echo "$events" | tail -5 | while read -r line; do
            echo "  $line"
        done
    else
        log_success "No recent warning events found"
    fi

    # Return findings as newline-separated string for parsing
    if [[ ${#findings[@]} -gt 0 ]]; then
        printf '%s\n' "${findings[@]}"
    fi
}

# =============================================================================
# NODE HEALTH DIAGNOSTICS
# =============================================================================
diagnose_node_issues() {
    echo "============================================================"
    echo "NODE DIAGNOSTICS"
    echo "Time: $(timestamp)"
    echo "============================================================"

    local findings=()

    # Get all nodes
    local nodes=$(kubectl get nodes -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)

    if [[ -z "$nodes" ]]; then
        log_warn "No nodes found in cluster"
        return 0
    fi

    for node in $nodes; do
        echo -e "\n${BLUE}[Node]${NC} $node"
        echo "----------------------------------------"

        # Get node status
        local status=$(kubectl get node "$node" -o jsonpath='{.status.conditions[*].type}' 2>/dev/null)

        for condition in $(echo "$status" | tr ' ' '\n'); do
            local cond_status=$(kubectl get node "$node" -o jsonpath="{.status.conditions[?(@.type=='$condition')].status}" 2>/dev/null || echo "")
            local reason=$(kubectl get node "$node" -o jsonpath="{.status.conditions[?(@.type=='$condition')].reason}" 2>/dev/null || echo "")

            if [[ "$cond_status" != "True" ]]; then
                case "$condition" in
                    MemoryPressure)
                        log_warn "Memory pressure: $reason"
                        findings+=("node:$node:condition:MemoryPressure")
                        ;;
                    DiskPressure)
                        log_warn "Disk pressure: $reason"
                        findings+=("node:$node:condition:DiskPressure")
                        ;;
                    PIDPressure)
                        log_warn "PID pressure: $reason"
                        findings+=("node:$node:condition:PIDPressure")
                        ;;
                    NotReady)
                        log_error "Node not ready: $reason"
                        findings+=("node:$node:condition:NotReady")
                        ;;
                esac
            fi
        done

        # Get node capacity info
        local cpu=$(kubectl get node "$node" -o jsonpath='{.status.capacity.cpu}' 2>/dev/null)
        local memory=$(kubectl get node "$node" -o jsonpath='{.status.capacity.memory}' 2>/dev/null)

        echo "  CPU: $cpu cores | Memory: $memory"
    done

    # Return findings
    if [[ ${#findings[@]} -gt 0 ]]; then
        printf '%s\n' "${findings[@]}"
    fi
}

# =============================================================================
# NETWORK TROUBLESHOOTING
# =============================================================================
diagnose_network_issues() {
    echo "============================================================"
    echo "NETWORK DIAGNOSTICS"
    echo "Namespace: $NAMESPACE | Time: $(timestamp)"
    echo "============================================================"

    local findings=()

    # Check CoreDNS status
    echo -e "\n${BLUE}[CoreDNS Status]${NC}"
    local coredns_ready=$(kubectl get pods -n kube-system -l k8s-app=dns -o jsonpath='{.items[*].status.containerStatuses[*].ready}' 2>/dev/null | grep -c true || echo "0")
    local coredns_total=$(kubectl get pods -n kube-system -l k8s-app=dns -o jsonpath='{.items[*].metadata.name}' 2>/dev/null | wc -w)

    if [[ "$coredns_ready" == "0" ]]; then
        log_error "No CoreDNS pods are ready!"
        findings+=("network:CoreDNS:no_pods_ready")
    else
        echo -e "  ${GREEN}CoreDNS:${NC} $coredns_ready/${coredns_total} ready"
    fi

    # Check service endpoints
    echo -e "\n${BLUE}[Service Endpoints]${NC}"
    local services=$(kubectl get services -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)

    if [[ -z "$services" ]]; then
        log_info "No services found in namespace $NAMESPACE"
    else
        for svc in $services; do
            local endpoints=$(kubectl get endpoints "$svc" -n "$NAMESPACE" -o jsonpath='{.subsets[*].addresses}' 2>/dev/null || echo "")

            if [[ -z "$endpoints" ]]; then
                log_warn "Service $svc has no ready endpoints"
                findings+=("service:$svc:no_endpoints")
            else
                local endpoint_count=$(echo "$endpoints" | tr ' ' '\n' | grep -c . || echo "0")
                echo "  $svc: $endpoint_count endpoints"
            fi
        done
    fi

    # Check for NetworkPolicies that might block traffic
    echo -e "\n${BLUE}[Network Policies]${NC}"
    local netpolicies=$(kubectl get networkpolicies -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)

    if [[ -z "$netpolicies" ]]; then
        log_info "No NetworkPolicies found (all traffic allowed by default)"
    else
        echo -e "  ${YELLOW}NetworkPolicies present:${NC} $netpolicies"
        log_warn "NetworkPolicies may restrict pod-to-pod communication"
        findings+=("network:NetworkPolicy:policies_present")
    fi

    # Return findings
    if [[ ${#findings[@]} -gt 0 ]]; then
        printf '%s\n' "${findings[@]}"
    fi
}

# =============================================================================
# RESOURCE CONSTRAINTS DIAGNOSTICS
# =============================================================================
diagnose_resource_constraints() {
    echo "============================================================"
    echo "RESOURCE CONSTRAINTS"
    echo "Namespace: $NAMESPACE | Time: $(timestamp)"
    echo "============================================================"

    local findings=()

    # Check node resource usage (requires metrics-server)
    echo -e "\n${BLUE}[Node Resource Usage]${NC}"
    if ! kubectl top nodes &>/dev/null; then
        log_warn "metrics-server not available. Cannot show real-time resource usage."
        log_info "Install metrics-server for CPU/memory metrics: https://github.com/kubernetes-sigs/metrics-server"
    else
        echo "$(kubectl top nodes --no-headers 2>/dev/null | while read -r line; do
            name=$(echo "$line" | awk '{print $1}')
            cpu=$(echo "$line" | awk '{print $2}')
            mem=$(echo "$line" | awk '{print $3}')
            echo "  $name: CPU=$cpu, Mem=$mem"
        done)"
    fi

    # Check PVC status
    echo -e "\n${BLUE}[Persistent Volume Claims]${NC}"
    local pvcs=$(kubectl get pvc -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null)

    if [[ -z "$pvcs" ]]; then
        log_info "No PVCs found in namespace $NAMESPACE"
    else
        for pvc in $pvcs; do
            local phase=$(kubectl get pvc "$pvc" -n "$NAMESPACE" -o jsonpath='{.status.phase}' 2>/dev/null || echo "Unknown")

            if [[ "$phase" != "Bound" ]]; then
                log_warn "PVC $pvc: $phase"
                findings+=("pvc:$pvc:not_bound:$phase")
            else
                local capacity=$(kubectl get pvc "$pvc" -n "$NAMESPACE" -o jsonpath='{.spec.resources.requests.storage}' 2>/dev/null)
                echo "  $pvc: ${GREEN}$phase${NC} ($capacity)"
            fi
        done
    fi

    # Check resource quotas
    echo -e "\n${BLUE}[Resource Quotas]${NC}"
    local quotas=$(kubectl get resourcequota -n "$NAMESPACE" -o jsonpath='{.items[*].metadata.name}' 2>/dev/null || true)

    if [[ -z "$quotas" ]]; then
        log_info "No ResourceQuotas defined in namespace $NAMESPACE"
    else
        for quota in $quotas; do
            local used=$(kubectl get resourcequota "$quota" -n "$NAMESPACE" -o jsonpath='{.status.used}' 2>/dev/null)
            local hard=$(kubectl get resourcequota "$quota" -n "$NAMESPACE" -o jsonpath='{.spec.hard}' 2>/dev/null)

            echo "  $quota: Used=$used, Hard=$hard"
        done
    fi

    # Return findings
    if [[ ${#findings[@]} -gt 0 ]]; then
        printf '%s\n' "${findings[@]}"
    fi
}

# =============================================================================
# GET POD LOGS
# =============================================================================
get_pod_logs() {
    local pod_name="${1:-}"
    local container_name="${2:-}"

    if [[ -z "$pod_name" ]]; then
        log_error "Usage: k8s-troubleshoot logs <pod-name> [container-name]"
        return 1
    fi

    echo "============================================================"
    echo "POD LOGS: $pod_name"
    echo "============================================================"

    local args=("-n" "$NAMESPACE" "logs" "$pod_name" "--tail=100")

    if [[ -n "$container_name" ]]; then
        args+=("-c" "$container_name")
    fi

    kubectl "${args[@]}" 2>/dev/null || log_error "Failed to get logs for pod $pod_name"
}

# =============================================================================
# DESCRIBE POD
# =============================================================================
describe_pod() {
    local pod_name="${1:-}"

    if [[ -z "$pod_name" ]]; then
        log_error "Usage: k8s-troubleshoot describe <pod-name>"
        return 1
    fi

    echo "============================================================"
    echo "POD DESCRIPTION: $pod_name"
    echo "============================================================"

    kubectl describe pod "$pod_name" -n "$NAMESPACE" 2>/dev/null || log_error "Failed to describe pod $pod_name"
}

# =============================================================================
# HELP
# =============================================================================
show_help() {
    cat << 'EOF'
Kubernetes Deep Troubleshooting Tool
=====================================

USAGE: k8s-troubleshoot <command> [options]

COMMANDS:
  pod [name]              Diagnose pod issues (all pods or specific)
  node                    Check all nodes for health issues
  network                 Troubleshoot cluster networking
  resources               Check resource constraints and quotas
  logs <pod> [container]  Get recent logs from a pod
  describe <pod>          Detailed pod description

ENVIRONMENT VARIABLES:
  K8S_NAMESPACE           Target namespace (default: default)
  K8S_VERBOSE             Verbosity level 0-3 (default: 1)

EXAMPLES:
  k8s-troubleshoot pod my-app-pod
  k8s-troubleshoot node
  k8s-troubleshoot network
  k8s-troubleshoot logs nginx-deployment-abc123
  K8S_NAMESPACE=production k8s-troubleshoot pod

REQUIREMENTS:
  - kubectl installed and configured
  - Access to a Kubernetes cluster
EOF
}

# =============================================================================
# MAIN ENTRY POINT
# =============================================================================
main() {
    if [[ $# -lt 1 ]]; then
        show_help
        exit 0
    fi

    # Check kubectl availability first
    check_kubectl

    local command="$1"
    shift

    case "$command" in
        pod)
            diagnose_pod_issues "$@"
            ;;
        node)
            diagnose_node_issues
            ;;
        network)
            diagnose_network_issues
            ;;
        resources)
            diagnose_resource_constraints
            ;;
        logs)
            get_pod_logs "$@"
            ;;
        describe)
            describe_pod "$@"
            ;;
        help|--help|-h)
            show_help
            ;;
        *)
            log_error "Unknown command: $command"
            echo ""
            show_help
            exit 1
            ;;
    esac
}

# Run main with all arguments
main "$@"
