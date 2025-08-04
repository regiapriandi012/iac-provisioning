# 🚀 Deployment Guide for Different Environments

This guide explains how to deploy this IaC pipeline in different environments without hardcoded paths or environment-specific configurations.

## 🌍 Environment-Agnostic Features

### ✅ **What's Already Dynamic:**
- **Workspace paths**: Uses `${WORKSPACE}` and `os.getcwd()` instead of hardcoded paths
- **Git repository**: Configurable via Jenkins parameter
- **User home directories**: Uses `{{ ansible_env.HOME }}` in Ansible
- **Kubeconfig locations**: Checks multiple user directories dynamically

### 🔧 **Configuration Files:**
- `config/environment.conf`: Environment-specific settings
- Jenkins parameters: Runtime configuration options

## 🏗️ Deployment Steps

### 1. **Fork/Clone Repository**
```bash
# Clone to your desired location
git clone https://github.com/your-org/iac-provision.git
cd iac-provision
```

### 2. **Update Configuration**
Edit `config/environment.conf` for your environment:
```bash
# Update Git repository URL
DEFAULT_GIT_REPOSITORY=https://your-git-server.com/your-org/iac-provision

# Update Proxmox settings
DEFAULT_PROXMOX_NODE=your-proxmox-node
DEFAULT_VM_TEMPLATE=your-vm-template

# Update network settings
DEFAULT_IP_RANGE_START=192.168.1.0/24
```

### 3. **Jenkins Setup**
1. **Create Jenkins Job**:
   - Pipeline job type
   - Point to your Git repository
   - Use `Jenkinsfile` from repository

2. **Configure Credentials** (customize IDs per environment):
   
   **Production Environment:**
   ```
   - prod-gitlab-credential: Git repository access
   - prod-proxmox-api-url: Production Proxmox API endpoint
   - prod-proxmox-api-token-id: Production Proxmox token ID
   - prod-proxmox-api-token-secret: Production Proxmox token secret
   - prod-slack-webhook-url: Production Slack webhook
   ```
   
   **Development Environment:**
   ```
   - dev-gitlab-credential: Git repository access
   - dev-proxmox-api-url: Development Proxmox API endpoint
   - dev-proxmox-api-token-id: Development Proxmox token ID
   - dev-proxmox-api-token-secret: Development Proxmox token secret
   - dev-slack-webhook-url: Development Slack webhook
   ```

3. **Set Parameters** (customize per environment):
   
   **Production Parameters:**
   ```
   git_repository_url: https://your-git-server.com/your-org/iac-provision
   git_credentials_id: prod-gitlab-credential
   proxmox_credentials_prefix: prod-proxmox
   slack_webhook_credential_id: prod-slack-webhook-url
   default_vm_template: ubuntu-22-04-prod
   default_proxmox_node: proxmox-prod-01
   vm_csv_content: (your production VM specifications)
   ```
   
   **Development Parameters:**
   ```
   git_repository_url: https://your-git-server.com/your-org/iac-provision
   git_credentials_id: dev-gitlab-credential
   proxmox_credentials_prefix: dev-proxmox
   slack_webhook_credential_id: dev-slack-webhook-url
   default_vm_template: ubuntu-22-04-dev
   default_proxmox_node: proxmox-dev-01
   vm_csv_content: (your development VM specifications)
   ```

### 4. **Environment-Specific Customization**

#### **For Different Operating Systems:**
Update VM templates and user configurations:
```yaml
# In Jenkinsfile parameters or environment.conf
DEFAULT_VM_TEMPLATE=ubuntu-22-04-template  # Ubuntu
DEFAULT_VM_TEMPLATE=centos-9-template      # CentOS
DEFAULT_ANSIBLE_USER=ansible               # Non-root user
```

#### **For Different Network Ranges:**
```csv
# Production Network (192.168.100.x)
vmid,vm_name,template,node,ip,cores,memory,disk_size
0,prod-k8s-master,ubuntu-22-04-prod,proxmox-prod-01,192.168.100.10,4,4096,50G
0,prod-k8s-worker01,ubuntu-22-04-prod,proxmox-prod-01,192.168.100.11,4,8192,100G

# Development Network (10.10.10.x)  
vmid,vm_name,template,node,ip,cores,memory,disk_size
0,dev-k8s-master,ubuntu-22-04-dev,proxmox-dev-01,10.10.10.10,2,2048,32G
0,dev-k8s-worker01,ubuntu-22-04-dev,proxmox-dev-01,10.10.10.11,2,4096,50G

# Using Placeholders (will be replaced by Jenkins parameters)
vmid,vm_name,template,node,ip,cores,memory,disk_size
0,kube-master,TEMPLATE_PLACEHOLDER,NODE_PLACEHOLDER,0,2,2048,32G
0,kube-worker01,TEMPLATE_PLACEHOLDER,NODE_PLACEHOLDER,0,2,2048,32G
```

#### **For Different Kubernetes Versions:**
```yaml
# Update in environment.conf or Ansible variables
DEFAULT_KUBERNETES_VERSION=1.29.0
```

### 5. **Path Customization**

#### **For Non-Root Users:**
The pipeline now automatically detects user home directories:
```yaml
# Ansible automatically uses current user's home
path: "{{ ansible_env.HOME }}/.kube"
dest: "{{ ansible_env.HOME }}/.kube/config"
```

#### **For Different Workspace Locations:**
Jenkins automatically sets `WORKSPACE` environment variable, and scripts use:
```python
workspace = os.environ.get('WORKSPACE', os.getcwd())
```

## 🔄 Migration from Existing Setup

### **From Original Repository:**
1. Fork the repository to your organization
2. Update `git_repository_url` parameter in Jenkins
3. Update `config/environment.conf` with your settings
4. Test with a single VM first

### **From Manual Setup:**
1. Export your current configurations:
   ```bash
   # Export Proxmox settings
   echo "PROXMOX_URL=https://your-proxmox:8006/api2/json" > current-config.env
   echo "PROXMOX_NODE=your-node" >> current-config.env
   ```

2. Map to new configuration format in `environment.conf`

3. Run test deployment

## 🧪 Testing Your Deployment

### **Validation Steps:**
1. **Dry Run**: Test with `use_cache=false` first
2. **Single VM**: Deploy one master node only
3. **Network Test**: Verify IP assignments work
4. **Full Cluster**: Deploy complete cluster

### **Common Issues & Solutions:**

#### **Path Issues:**
```bash
# If you see hardcoded paths in logs, check:
grep -r "/root/" scripts/
grep -r "iac-provision" scripts/
```

#### **Permission Issues:**
```bash
# Ensure proper user permissions:
# For non-root users, update DEFAULT_ANSIBLE_USER in environment.conf
```

#### **Network Issues:**
```bash
# Update IP ranges in your VM CSV:
# Ensure IPs don't conflict with existing infrastructure
```

## 🚀 Advanced Customization

### **Custom Scripts Location:**
Scripts automatically detect workspace:
```bash
WORKSPACE=/your/custom/path jenkins-job
```

### **Custom Cache Location:**
```bash
# Update in environment.conf
CACHE_LOCATION=/your/custom/cache/path
```

### **Custom Notification:**
```bash
# Update Slack webhook or disable notifications
SLACK_ENABLED=false
```

## 📋 Environment Checklist

Before deploying in a new environment, verify:

- [ ] Git repository accessible from Jenkins
- [ ] Proxmox credentials configured
- [ ] Network ranges available and non-conflicting
- [ ] VM templates exist in Proxmox
- [ ] Jenkins has necessary plugins (Git, Pipeline)
- [ ] Slack webhook configured (if using notifications)
- [ ] Python 3 and pip available on Jenkins node
- [ ] Ansible requirements can be installed

## 🔧 Troubleshooting

### **Debug Mode:**
Enable debug logging by setting in Jenkinsfile:
```groovy
environment {
    DEBUG_MODE = 'true'
}
```

### **Path Debugging:**
Check all paths are dynamic:
```bash
# Should not return any results:
grep -r "/root/coder/iac-provision" .
grep -r "labngoprek" . --exclude-dir=.git
```

### **Test Script Portability:**
```bash
# Test scripts work from any directory:
cd /tmp
/path/to/your/iac-provision/scripts/setup_environment.sh
```

This deployment guide ensures your IaC pipeline works in any environment without hardcoded dependencies!