#!/bin/bash
# Generate vms.csv dynamically based on environment.conf

set -e

# Load environment configuration using load_environment.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Store original env vars for override capability
ORIGINAL_MASTER_COUNT=${DEFAULT_MASTER_COUNT}
ORIGINAL_WORKER_COUNT=${DEFAULT_WORKER_COUNT}
ORIGINAL_VM_TEMPLATE=${DEFAULT_VM_TEMPLATE}
ORIGINAL_PROXMOX_NODE=${DEFAULT_PROXMOX_NODE}
ORIGINAL_CORES=${DEFAULT_CORES}
ORIGINAL_MEMORY=${DEFAULT_MEMORY}
ORIGINAL_DISK_SIZE=${DEFAULT_DISK_SIZE}

# Load environment using the standardized script
echo "Loading environment configuration..." >&2
source "${SCRIPT_DIR}/load_environment.sh" > /dev/null 2>&1

# Apply overrides if they were provided as environment variables
if [ -n "$ORIGINAL_MASTER_COUNT" ]; then
    DEFAULT_MASTER_COUNT="$ORIGINAL_MASTER_COUNT"
fi
if [ -n "$ORIGINAL_WORKER_COUNT" ]; then
    DEFAULT_WORKER_COUNT="$ORIGINAL_WORKER_COUNT"  
fi
if [ -n "$ORIGINAL_VM_TEMPLATE" ]; then
    DEFAULT_VM_TEMPLATE="$ORIGINAL_VM_TEMPLATE"
fi
if [ -n "$ORIGINAL_PROXMOX_NODE" ]; then
    DEFAULT_PROXMOX_NODE="$ORIGINAL_PROXMOX_NODE"
fi
if [ -n "$ORIGINAL_CORES" ]; then
    DEFAULT_CORES="$ORIGINAL_CORES"
fi
if [ -n "$ORIGINAL_MEMORY" ]; then
    DEFAULT_MEMORY="$ORIGINAL_MEMORY"
fi
if [ -n "$ORIGINAL_DISK_SIZE" ]; then
    DEFAULT_DISK_SIZE="$ORIGINAL_DISK_SIZE"
fi

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