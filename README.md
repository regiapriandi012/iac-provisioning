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
   - `run_ansible`: true (deploy Kubernetes)
   - `skip_verification`: false (verify cluster)

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

```csv
vmid,vm_name,template,node,ip,cores,memory,disk_size
0,kube-master,debian-12,node1,0,4,8192,50G
0,kube-worker01,debian-12,node1,0,4,8192,100G
0,kube-worker02,debian-12,node1,0,4,8192,100G
```

**Note**: Use `0` for auto-assignment of VMID and IP addresses

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
- Configures networking (Flannel CNI)
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

### Destroying Infrastructure

```bash
cd terraform
terraform destroy --auto-approve
```

**Warning**: This permanently deletes all VMs!

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