# Ansible Kubernetes Setup

This directory contains Ansible playbooks and scripts for setting up Kubernetes clusters on VMs provisioned by Terraform.

## Quick Start

```bash
# After Terraform provisions VMs, run:
./run-k8s-setup.sh
```

## Architecture

1. **Terraform** provisions VMs and outputs inventory as JSON
2. **inventory.py** converts JSON to Ansible dynamic inventory format
3. **Ansible playbook** configures Kubernetes on all nodes

## Key Files

- `ansible.cfg` - Ansible configuration (SSH settings, timeouts, etc)
- `inventory.py` - Dynamic inventory script (reads from inventory/k8s-inventory.json)
- `run-k8s-setup.sh` - Main orchestration script
- `playbooks/k8s-cluster-setup.yml` - Kubernetes setup playbook

## Workflow

1. Jenkins runs Terraform to provision VMs
2. Terraform outputs `ansible_inventory_json`
3. Jenkins saves this to `inventory/k8s-inventory.json`
4. run-k8s-setup.sh uses inventory.py to parse JSON
5. Ansible playbook installs and configures Kubernetes

## Inventory Format

The inventory JSON must contain:
- `k8s_masters` - Master node group
- `k8s_workers` - Worker node group  
- `k8s_cluster` - Parent group containing both
- Global vars like `kubernetes_version`, `pod_network_cidr`, etc

## Troubleshooting

### SSH Connection Issues
- Check ansible.cfg for SSH settings
- Ensure no duplicate ansible_ssh_common_args

### Inventory Issues
- Verify inventory/k8s-inventory.json exists
- Run `./inventory.py --list` to test parsing

### Package Installation
- Playbook adds Docker repo for containerd
- Supports both RedHat and Debian families

See SCRIPTS.md for detailed script documentation.