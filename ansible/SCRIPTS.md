# Ansible Scripts Documentation

## Main Scripts

### inventory.py
Dynamic inventory script that reads from k8s-inventory.json and converts it to Ansible format.
Used by all Ansible commands to parse the JSON inventory.

### generate_simple_inventory.py
Generates k8s-inventory.json from Terraform CSV output (vms.csv).
Called by run-k8s-setup.sh when inventory doesn't exist.

### run-k8s-setup.sh
Main orchestration script that:
- Checks prerequisites
- Generates inventory from CSV if needed
- Tests connectivity
- Runs the Kubernetes setup playbook

## Utility Scripts (scripts/)

### get_first_master.py
Returns the hostname of the first master node from inventory.
Used by Jenkins to run kubectl commands on master.

### get_kubeconfig_v2.py
Retrieves KUBECONFIG from master node and saves it locally.
Used by Jenkins to extract cluster access credentials.

### smart_vm_ready.py
Smart parallel VM readiness checker using TCP connectivity.
Replaces slow sequential netcat checks.

## Playbooks

### playbooks/k8s-cluster-setup.yml
Main Kubernetes cluster setup playbook that:
- Configures system prerequisites
- Installs container runtime (containerd)
- Installs Kubernetes components
- Initializes cluster
- Joins worker nodes
- Installs CNI (Cilium)