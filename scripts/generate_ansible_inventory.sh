#!/bin/bash
# Generate Ansible inventory with dynamic CNI configuration
set -e

CSV_FILE=${1:-"../terraform/vms.csv"}
OUTPUT_FILE=${2:-"inventory/k8s-inventory.json"}

# Create output directory if it doesn't exist
mkdir -p "$(dirname "$OUTPUT_FILE")"

# Check if we have Jenkins parameters for CNI configuration
if [ -n "$TF_VAR_cni_type" ] && [ -n "$TF_VAR_cni_version" ]; then
    echo "Using CNI configuration from Jenkins parameters:"
    echo "  CNI Type: $TF_VAR_cni_type"
    echo "  CNI Version: $TF_VAR_cni_version"
    
    # Export environment variables for the Python script
    export CNI_TYPE="$TF_VAR_cni_type"
    export CNI_VERSION="$TF_VAR_cni_version"
    
    # Use the new CNI-aware script
    python3 "$(dirname "$0")/generate_inventory_with_cni.py" "$CSV_FILE" > "$OUTPUT_FILE"
else
    echo "No CNI parameters provided, using default configuration"
    # Fall back to the original script
    python3 "$(dirname "$0")/generate_simple_inventory.py" "$CSV_FILE" > "$OUTPUT_FILE"
fi

echo "Ansible inventory generated at: $OUTPUT_FILE"

# Validate the generated inventory
if [ -f "$OUTPUT_FILE" ]; then
    echo "Inventory validation:"
    echo "  File size: $(wc -c < "$OUTPUT_FILE") bytes"
    echo "  Masters: $(cat "$OUTPUT_FILE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data.get('k8s_masters', {}).get('hosts', {})))")"
    echo "  Workers: $(cat "$OUTPUT_FILE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(len(data.get('k8s_workers', {}).get('hosts', {})))")"
    echo "  CNI Type: $(cat "$OUTPUT_FILE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('all', {}).get('vars', {}).get('cni_type', 'unknown'))")"
    echo "  CNI Version: $(cat "$OUTPUT_FILE" | python3 -c "import sys, json; data=json.load(sys.stdin); print(data.get('all', {}).get('vars', {}).get('cni_version', 'unknown'))")"
else
    echo "ERROR: Failed to generate inventory file"
    exit 1
fi