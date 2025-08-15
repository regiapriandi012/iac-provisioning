#!/bin/bash
# Generate vms.csv dynamically based on environment.conf

set -e

# Load environment configuration (but allow env vars to override)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="${SCRIPT_DIR}/../config/environment.conf"

# Store env vars before sourcing config file
OVERRIDE_VM_TEMPLATE=${DEFAULT_VM_TEMPLATE}
OVERRIDE_PROXMOX_NODE=${DEFAULT_PROXMOX_NODE}
OVERRIDE_CORES=${DEFAULT_CORES}
OVERRIDE_MEMORY=${DEFAULT_MEMORY}
OVERRIDE_DISK_SIZE=${DEFAULT_DISK_SIZE}
OVERRIDE_MASTER_COUNT=${DEFAULT_MASTER_COUNT}
OVERRIDE_WORKER_COUNT=${DEFAULT_WORKER_COUNT}

if [ -f "$CONFIG_FILE" ]; then
    source "$CONFIG_FILE"
else
    echo "Error: environment.conf not found"
    exit 1
fi

# Use overrides if provided, otherwise use config values, otherwise use defaults
DEFAULT_VM_TEMPLATE=${OVERRIDE_VM_TEMPLATE:-${DEFAULT_VM_TEMPLATE:-"t-debian12-86"}}
DEFAULT_PROXMOX_NODE=${OVERRIDE_PROXMOX_NODE:-${DEFAULT_PROXMOX_NODE:-"proxmox"}}
DEFAULT_CORES=${OVERRIDE_CORES:-${DEFAULT_CORES:-2}}
DEFAULT_MEMORY=${OVERRIDE_MEMORY:-${DEFAULT_MEMORY:-2048}}
DEFAULT_DISK_SIZE=${OVERRIDE_DISK_SIZE:-${DEFAULT_DISK_SIZE:-"32G"}}
DEFAULT_MASTER_COUNT=${OVERRIDE_MASTER_COUNT:-${DEFAULT_MASTER_COUNT:-3}}
DEFAULT_WORKER_COUNT=${OVERRIDE_WORKER_COUNT:-${DEFAULT_WORKER_COUNT:-2}}

# Output file
OUTPUT_FILE="${SCRIPT_DIR}/../vms.csv"

echo "🔧 Generating vms.csv with dynamic configuration:"
echo "   Template: ${DEFAULT_VM_TEMPLATE}"
echo "   Node: ${DEFAULT_PROXMOX_NODE}"
echo "   Masters: ${DEFAULT_MASTER_COUNT}, Workers: ${DEFAULT_WORKER_COUNT}"
echo "   Cores: ${DEFAULT_CORES}, Memory: ${DEFAULT_MEMORY}, Disk: ${DEFAULT_DISK_SIZE}"

# Generate vms.csv header
echo "vmid,vm_name,template,node,ip,cores,memory,disk_size" > "$OUTPUT_FILE"

# Generate master nodes
for i in $(seq 1 $DEFAULT_MASTER_COUNT); do
    master_name="kube-master$(printf "%02d" $i)"
    echo "0,${master_name},${DEFAULT_VM_TEMPLATE},${DEFAULT_PROXMOX_NODE},0,${DEFAULT_CORES},${DEFAULT_MEMORY},${DEFAULT_DISK_SIZE}" >> "$OUTPUT_FILE"
done

# Generate worker nodes
for i in $(seq 1 $DEFAULT_WORKER_COUNT); do
    worker_name="kube-worker$(printf "%02d" $i)"
    echo "0,${worker_name},${DEFAULT_VM_TEMPLATE},${DEFAULT_PROXMOX_NODE},0,${DEFAULT_CORES},${DEFAULT_MEMORY},${DEFAULT_DISK_SIZE}" >> "$OUTPUT_FILE"
done

echo "✅ Generated vms.csv:"
echo "   Total VMs: $((DEFAULT_MASTER_COUNT + DEFAULT_WORKER_COUNT))"
echo "   Masters: ${DEFAULT_MASTER_COUNT} (kube-master01 to kube-master$(printf "%02d" $DEFAULT_MASTER_COUNT))"
echo "   Workers: ${DEFAULT_WORKER_COUNT} (kube-worker01 to kube-worker$(printf "%02d" $DEFAULT_WORKER_COUNT))"
echo "   File: $OUTPUT_FILE"