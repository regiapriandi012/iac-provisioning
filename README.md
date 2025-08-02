# Infrastructure as Code - Kubernetes on Proxmox

Automated provisioning of Kubernetes clusters on Proxmox VE using Terraform and Ansible, orchestrated by Jenkins CI/CD.

## 🏗️ Architecture Overview

```
Jenkins Pipeline
    ├── Terraform (VM Provisioning)
    │   ├── Creates VMs on Proxmox
    │   ├── Assigns random IPs/IDs
    │   └── Outputs inventory JSON
    │
    └── Ansible (Kubernetes Setup)
        ├── Configures OS prerequisites
        ├── Installs container runtime
        └── Deploys Kubernetes cluster
```

## 🚀 Quick Start

### Prerequisites

- Proxmox VE server with templates configured
- Jenkins server with:
  - Terraform installed
  - Ansible installed
  - Git credentials configured
- Network connectivity to Proxmox API

### Manual Deployment

```bash
# 1. Provision VMs with Terraform
cd terraform
terraform init
terraform plan
terraform apply

# 2. Setup Kubernetes with Ansible
cd ../ansible
./run-k8s-setup.sh
```

### Jenkins Deployment

1. Create Jenkins pipeline job
2. Point to this repository
3. Run pipeline with parameters:
   - `cluster_preset`: Choose from presets or 'custom'
     - `small-single-master`: 1 master + 2 workers (2 cores, 4GB RAM)
     - `medium-single-master`: 1 master + 3 workers (4 cores, 8GB RAM)
     - `ha-3-masters`: 3 masters + 3 workers (4 cores, 8GB RAM) - HA setup
     - `custom`: Use your own CSV configuration
   - `vm_template`: Select VM template
     - `t-debian-12`: Debian 12 (Bookworm)
     - `t-ubuntu-22.04`: Ubuntu 22.04 LTS
     - `t-centos9-86`: CentOS 9 Stream
     - `t-rocky-9`: Rocky Linux 9
   - `proxmox_node`: Proxmox node name (default: thinkcentre)
   - `vm_csv_content`: Custom CSV content (when preset is 'custom')
   - `run_ansible`: true (deploy Kubernetes)
   - `skip_verification`: false (verify cluster)

**Dynamic VM Configuration**: 
- Select a preset for quick deployment
- Or choose 'custom' and paste your own CSV configuration
- CSV format must include: vmid,vm_name,template,node,ip,cores,memory,disk_size

**Important**: 
- Each Jenkins run creates **NEW VMs** without destroying previous ones
- Old VMs remain running (useful for testing multiple clusters)
- Terraform state is backed up to `terraform/state_backups/` with timestamp
- To remove old VMs, manually run `terraform destroy` with the backed-up state

## 📁 Project Structure

```
iac-provision/
├── Jenkinsfile              # CI/CD pipeline definition
├── terraform/               # Infrastructure provisioning
│   ├── main.tf             # VM resources definition
│   ├── variables.tf        # Input variables
│   ├── outputs.tf          # JSON inventory output
│   └── vms.csv             # VM specifications
│
└── ansible/                # Configuration management
    ├── inventory.py        # Dynamic inventory script
    ├── playbooks/          # Ansible playbooks
    │   └── k8s-cluster-setup.yml
    ├── scripts/            # Utility scripts
    └── run-k8s-setup.sh    # Main orchestrator
```

## 🔧 Configuration

### Terraform Variables (terraform.tfvars)

```hcl
proxmox_api_url = "https://proxmox.example.com:8006/api2/json"
proxmox_node    = "node-name"
vm_template     = "debian-12-template"
network_bridge  = "vmbr0"
storage_pool    = "local-lvm"
```

### VM Specifications (terraform/vms.csv)

**Single Master Setup:**
```csv
vmid,vm_name,template,node,ip,cores,memory,disk_size
0,kube-master,debian-12,node1,0,4,8192,50G
0,kube-worker01,debian-12,node1,0,4,8192,100G
0,kube-worker02,debian-12,node1,0,4,8192,100G
```

**Multi-Master HA Setup:**
```csv
vmid,vm_name,template,node,ip,cores,memory,disk_size
0,kube-master01,debian-12,node1,0,4,8192,50G
0,kube-master02,debian-12,node1,0,4,8192,50G
0,kube-master03,debian-12,node1,0,4,8192,50G
0,kube-worker01,debian-12,node1,0,4,8192,100G
0,kube-worker02,debian-12,node1,0,4,8192,100G
```

**Note**: 
- Use `0` for auto-assignment of VMID and IP addresses
- For HA setup, the first IP (base-1) is reserved for HAProxy VIP
- Example: If base IP is 10, then VIP=9, master1=10, master2=11, etc.

## 🔄 Workflow

### 1. Infrastructure Provisioning (Terraform)

- Reads VM specifications from CSV
- Auto-generates unique VMIDs (100-999 range)
- Auto-assigns sequential IPs from random base
- Creates VMs with random suffix for uniqueness
- Outputs Ansible inventory as JSON

### 2. Kubernetes Deployment (Ansible)

- Detects OS type from template name
- Configures system prerequisites
- Installs Docker repository and containerd
- Deploys Kubernetes using kubeadm
- Configures networking (Cilium CNI)
- Joins worker nodes to cluster

### 3. Post-Deployment

- Extracts kubeconfig for cluster access
- Displays cluster endpoints
- Archives configuration in Jenkins

## 📊 Inventory Management

The system uses dynamic inventory generation:

1. **Terraform Output** → `ansible_inventory_json`
2. **JSON File** → `inventory/k8s-inventory.json`
3. **Dynamic Script** → `inventory.py` converts to Ansible format

Example inventory structure:
```json
{
  "k8s_masters": {
    "hosts": {
      "kube-master-abc123": {
        "ansible_host": "10.200.0.10",
        "template": "debian-12"
      }
    }
  },
  "k8s_workers": {
    "hosts": {
      "kube-worker01-abc123": {
        "ansible_host": "10.200.0.11"
      }
    }
  }
}
```

## 🛠️ Troubleshooting

### Common Issues

#### SSH Connection Errors
```bash
# Check SSH connectivity
ansible all -i ansible/inventory.py -m ping

# Verify ansible.cfg SSH settings
cat ansible/ansible.cfg
```

#### Package Installation Failures
- Ensure Docker repository is added (handled by playbook)
- Check internet connectivity from VMs
- Verify DNS resolution

#### Inventory Not Found
```bash
# Regenerate inventory from Terraform
cd terraform
terraform output -raw ansible_inventory_json > ../ansible/inventory/k8s-inventory.json
```

### Debug Commands

```bash
# Test inventory parsing
cd ansible
./inventory.py --list

# Check cluster status
ansible kube-master* -i inventory.py -m shell -a "kubectl get nodes"

# View cluster endpoints
python3 scripts/show_endpoints.py inventory/k8s-inventory.json
```

## 🔐 Security Considerations

- SSH keys should be pre-configured in VM templates
- Use secure Proxmox API tokens (not root credentials)
- Store sensitive variables in Jenkins credentials
- Network isolation for Kubernetes nodes recommended

## 📝 Maintenance

### Adding New Nodes

1. Add entries to `terraform/vms.csv`
2. Run Terraform apply
3. Run Ansible playbook
4. New workers auto-join existing cluster

### Managing Multiple Deployments

Since each Jenkins run creates new VMs:

#### View All Running VMs
```bash
# Check current deployment
cd terraform
terraform state list

# Check previous deployments (in Proxmox UI or via API)
```

#### Destroy Current Deployment
```bash
cd terraform
terraform destroy --auto-approve
```

#### Destroy Previous Deployments
```bash
cd terraform/state_backups
# Find the state file you want
terraform destroy --state=terraform.tfstate.20240102_143022 --auto-approve
```

**Warning**: Destroy commands permanently delete VMs!

## 🤝 Contributing

1. Fork the repository
2. Create feature branch
3. Test changes in dev environment
4. Submit pull request

## 📄 License

This project is licensed under the MIT License.

## 🙏 Acknowledgments

- Built for automated Kubernetes deployments
- Optimized for Proxmox VE environments
- Jenkins pipeline for CI/CD integration