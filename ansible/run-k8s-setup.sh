#!/bin/bash
#
# Dynamic Kubernetes Cluster Setup Script
# Automatically detects single master or HA multi-master setup
#

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
CSV_FILE="${CSV_FILE:-../terraform/vms.csv}"
INVENTORY_SCRIPT="./generate_inventory.py"
PLAYBOOK="./playbooks/k8s-cluster-setup.yml"
INVENTORY_FILE="inventory/k8s-inventory.json"
INVENTORY_SCRIPT="./inventory.py"

# Functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_banner() {
    echo -e "${GREEN}"
    echo "=================================================================="
    echo "          Dynamic Kubernetes Cluster Setup"
    echo "=================================================================="
    echo -e "${NC}"
}

check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check if CSV file exists
    if [[ ! -f "$CSV_FILE" ]]; then
        log_error "CSV file not found: $CSV_FILE"
        exit 1
    fi
    
    # Check if Python is available
    if ! command -v python3 &> /dev/null; then
        log_error "Python3 is required but not installed"
        exit 1
    fi
    
    # Check if Ansible is available
    if ! command -v ansible-playbook &> /dev/null; then
        log_error "Ansible is required but not installed"
        exit 1
    fi
    
    # Make inventory script executable
    chmod +x "$INVENTORY_SCRIPT"
    
    log_success "Prerequisites check passed"
}

generate_inventory() {
    # Check if inventory already exists and is valid
    if [[ -f "$INVENTORY_FILE" ]] && python3 -m json.tool "$INVENTORY_FILE" > /dev/null 2>&1; then
        log_success "Using existing valid inventory file: $INVENTORY_FILE"
        return 0
    fi
    
    log_info "Generating simple inventory from CSV (avoiding phantom host issues)..."
    
    # Use simple generator to avoid parsing issues
    if python3 generate_simple_inventory.py "$CSV_FILE" > "$INVENTORY_FILE"; then
        log_success "Inventory generated from CSV"
        
        # Parse and display cluster configuration
        MASTER_COUNT=$(python3 -c "
import json
with open('$INVENTORY_FILE', 'r') as f:
    inv = json.load(f)
    print(inv['all']['vars']['master_count'])
")
        
        IS_HA=$(python3 -c "
import json
with open('$INVENTORY_FILE', 'r') as f:
    inv = json.load(f)
    print('true' if inv['all']['vars']['is_ha_cluster'] else 'false')
")
        
        echo -e "${BLUE}Cluster Configuration:${NC}"
        echo "  Master Nodes: $MASTER_COUNT"
        echo "  Mode: $([ "$IS_HA" = "true" ] && echo "HA Multi-Master" || echo "Single Master")"
        echo "  HAProxy LB: $([ "$IS_HA" = "true" ] && echo "Enabled" || echo "Disabled")"
        
    else
        log_error "Failed to generate inventory from CSV"
        exit 1
    fi
}

run_playbook() {
    log_info "Starting Kubernetes cluster setup..."
    
    log_info "Testing inventory and connectivity first..."
    
    # Set environment variable for dynamic inventory script
    export ANSIBLE_INVENTORY_FILE="$INVENTORY_FILE"
    
    # Test inventory parsing
    ansible-inventory -i "$INVENTORY_SCRIPT" --list > /dev/null || {
        log_error "Failed to parse inventory file"
        exit 1
    }
    
    # Test basic connectivity with proper timeout (exclude phantom hosts)
    log_info "Testing connectivity to all hosts..."
    ansible k8s_masters:k8s_workers -i "$INVENTORY_SCRIPT" -m ping --timeout=30 -o \
        -e ansible_ssh_common_args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" || {
        log_warning "Some hosts may not be reachable yet, continuing anyway..."
    }
    
    # Run the playbook with generated inventory
    ansible-playbook \
        -i "$INVENTORY_SCRIPT" \
        "$PLAYBOOK" \
        -v \
        -e ansible_ssh_common_args="-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null" \
        "$@"
    
    if [[ $? -eq 0 ]]; then
        log_success "Kubernetes cluster setup completed successfully!"
        print_next_steps
    else
        log_error "Kubernetes cluster setup failed"
        exit 1
    fi
}

print_next_steps() {
    echo -e "${GREEN}"
    echo "=================================================================="
    echo "                    Setup Complete!"
    echo "=================================================================="
    echo -e "${NC}"
    
    echo "Next steps:"
    echo "1. SSH to your master node"
    echo "2. Run: kubectl get nodes"
    echo "3. Run: kubectl get pods --all-namespaces"
    
    if [[ "$IS_HA" = "true" ]]; then
        echo "4. Check HAProxy stats: http://<master-ip>:8404/stats"
        echo "5. Test HA by stopping one master node"
    fi
    
    echo ""
    echo "Useful commands:"
    echo "  kubectl cluster-info"
    echo "  kubectl get nodes -o wide"
    echo "  kubectl get pods --all-namespaces"
    echo "  kubectl describe node <node-name>"
}

show_help() {
    echo "Usage: $0 [OPTIONS]"
    echo ""
    echo "Options:"
    echo "  -h, --help              Show this help message"
    echo "  -c, --csv-file FILE     Specify CSV file path (default: ../terraform/vms.csv)"
    echo "  -v, --verbose           Enable verbose Ansible output"
    echo "  --check                 Run in check mode (dry-run)"
    echo "  --skip-tags TAGS        Skip specific Ansible tags"
    echo "  --tags TAGS             Run only specific Ansible tags"
    echo ""
    echo "Examples:"
    echo "  $0                                          # Basic run"
    echo "  $0 -c /path/to/vms.csv                     # Custom CSV file"
    echo "  $0 --check                                 # Dry run"
    echo "  $0 --tags common                           # Only run common tasks"
}

# Main execution
main() {
    print_banner
    
    # Parse command line arguments
    ANSIBLE_ARGS=()
    
    while [[ $# -gt 0 ]]; do
        case $1 in
            -h|--help)
                show_help
                exit 0
                ;;
            -c|--csv-file)
                CSV_FILE="$2"
                shift 2
                ;;
            -v|--verbose)
                ANSIBLE_ARGS+=("-vvv")
                shift
                ;;
            --check)
                ANSIBLE_ARGS+=("--check")
                shift
                ;;
            --skip-tags)
                ANSIBLE_ARGS+=("--skip-tags" "$2")
                shift 2
                ;;
            --tags)
                ANSIBLE_ARGS+=("--tags" "$2")
                shift 2
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
    
    # Execute main workflow
    check_prerequisites
    generate_inventory
    run_playbook "${ANSIBLE_ARGS[@]}"
}

# Trap for cleanup
cleanup() {
    log_info "Cleaning up temporary files..."
    # Don't remove inventory file as it's needed by show_endpoints.py
    # [[ -f "$INVENTORY_FILE" ]] && rm -f "$INVENTORY_FILE"
}

# Disable cleanup trap as we need the inventory file for Jenkins
# trap cleanup EXIT

# Run main function
main "$@"