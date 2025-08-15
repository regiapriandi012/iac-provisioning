#!/bin/bash
# Load environment configuration and export as environment variables
# This ensures all environment.conf settings are available to all scripts

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/environment.conf"

if [ ! -f "$CONFIG_FILE" ]; then
    echo "Error: environment.conf not found at $CONFIG_FILE"
    exit 1
fi

echo "🔧 Loading environment configuration..."

# Store environment overrides before sourcing config file
OVERRIDE_PROXMOX_NODE=${DEFAULT_PROXMOX_NODE}
OVERRIDE_VM_TEMPLATE=${DEFAULT_VM_TEMPLATE}
OVERRIDE_MASTER_COUNT=${DEFAULT_MASTER_COUNT}
OVERRIDE_WORKER_COUNT=${DEFAULT_WORKER_COUNT}
OVERRIDE_CORES=${DEFAULT_CORES}
OVERRIDE_MEMORY=${DEFAULT_MEMORY}
OVERRIDE_DISK_SIZE=${DEFAULT_DISK_SIZE}
OVERRIDE_KUBERNETES_VERSION=${DEFAULT_KUBERNETES_VERSION}
OVERRIDE_POD_CIDR=${DEFAULT_POD_NETWORK_CIDR}
OVERRIDE_SERVICE_CIDR=${DEFAULT_SERVICE_CIDR}
OVERRIDE_CNI_TYPE=${DEFAULT_CNI_TYPE}
OVERRIDE_CNI_VERSION=${DEFAULT_CNI_VERSION}

# Source the config file
source "$CONFIG_FILE"

# Use overrides if provided, otherwise use config values, otherwise use defaults
DEFAULT_PROXMOX_NODE=${OVERRIDE_PROXMOX_NODE:-${DEFAULT_PROXMOX_NODE:-"proxmox"}}
DEFAULT_VM_TEMPLATE=${OVERRIDE_VM_TEMPLATE:-${DEFAULT_VM_TEMPLATE:-"t-debian12-86"}}
DEFAULT_MASTER_COUNT=${OVERRIDE_MASTER_COUNT:-${DEFAULT_MASTER_COUNT:-3}}
DEFAULT_WORKER_COUNT=${OVERRIDE_WORKER_COUNT:-${DEFAULT_WORKER_COUNT:-2}}
DEFAULT_CORES=${OVERRIDE_CORES:-${DEFAULT_CORES:-2}}
DEFAULT_MEMORY=${OVERRIDE_MEMORY:-${DEFAULT_MEMORY:-2048}}
DEFAULT_DISK_SIZE=${OVERRIDE_DISK_SIZE:-${DEFAULT_DISK_SIZE:-"32G"}}
DEFAULT_KUBERNETES_VERSION=${OVERRIDE_KUBERNETES_VERSION:-${DEFAULT_KUBERNETES_VERSION:-"1.32.7"}}
DEFAULT_POD_NETWORK_CIDR=${OVERRIDE_POD_CIDR:-${DEFAULT_POD_NETWORK_CIDR:-"10.244.0.0/16"}}
DEFAULT_SERVICE_CIDR=${OVERRIDE_SERVICE_CIDR:-${DEFAULT_SERVICE_CIDR:-"10.96.0.0/12"}}
DEFAULT_CNI_TYPE=${OVERRIDE_CNI_TYPE:-${DEFAULT_CNI_TYPE:-"cilium"}}
DEFAULT_CNI_VERSION=${OVERRIDE_CNI_VERSION:-${DEFAULT_CNI_VERSION:-"1.14.5"}}

# Export all DEFAULT_* variables as TF_VAR_* for Terraform
export TF_VAR_proxmox_node=${DEFAULT_PROXMOX_NODE}
export TF_VAR_vm_template=${DEFAULT_VM_TEMPLATE}
export TF_VAR_master_node_count=${DEFAULT_MASTER_COUNT}
export TF_VAR_worker_node_count=${DEFAULT_WORKER_COUNT}
export TF_VAR_vm_cores=${DEFAULT_CORES}
export TF_VAR_vm_memory=${DEFAULT_MEMORY}
export TF_VAR_vm_disk_size=${DEFAULT_DISK_SIZE}
export TF_VAR_kubernetes_version=${DEFAULT_KUBERNETES_VERSION}
export TF_VAR_pod_network_cidr=${DEFAULT_POD_NETWORK_CIDR}
export TF_VAR_service_cidr=${DEFAULT_SERVICE_CIDR}
export TF_VAR_container_runtime=${DEFAULT_CONTAINER_RUNTIME:-"containerd"}
export TF_VAR_cni_type=${DEFAULT_CNI_TYPE}
export TF_VAR_cni_version=${DEFAULT_CNI_VERSION}
export TF_VAR_ip_range_start=${DEFAULT_IP_RANGE_START:-"10.200.0.0/24"}

# Export Ansible variables
export ANSIBLE_USER=${DEFAULT_ANSIBLE_USER:-"root"}
export ANSIBLE_SSH_USER=${DEFAULT_SSH_USER:-"root"}
export ANSIBLE_FORKS=${DEFAULT_FORKS:-100}

# Export deployment options
export ENABLE_CACHE=${ENABLE_CACHE_BY_DEFAULT:-true}
export PARALLEL_DEPLOYMENT=${PARALLEL_DEPLOYMENT:-true}

# Export Jenkins variables
export RUN_ANSIBLE=${RUN_ANSIBLE:-true}
export USE_CACHE=${USE_CACHE:-true}

echo "✅ Environment loaded:"
echo "   Template: ${DEFAULT_VM_TEMPLATE}"
echo "   Cluster: ${DEFAULT_MASTER_COUNT} masters, ${DEFAULT_WORKER_COUNT} workers"
echo "   Kubernetes: v${DEFAULT_KUBERNETES_VERSION}"
echo "   CNI: ${DEFAULT_CNI_TYPE} v${DEFAULT_CNI_VERSION}"
echo "   Resources: ${DEFAULT_CORES}c/${DEFAULT_MEMORY}MB/${DEFAULT_DISK_SIZE}"
echo "   Parallel: ${PARALLEL_DEPLOYMENT}"

# If run directly, show exported variables
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    echo ""
    echo "🌍 Exported Terraform variables:"
    env | grep "^TF_VAR_" | sort
    echo ""
    echo "🔧 Exported Ansible variables:"  
    env | grep "^ANSIBLE_" | sort
fi