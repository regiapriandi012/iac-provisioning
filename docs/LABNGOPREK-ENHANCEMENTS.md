# LABNGOPREK Kubernetes Cluster Enhancements

This document describes the LABNGOPREK-specific enhancements that are automatically applied to all Kubernetes clusters during the provisioning process.

## 🎯 Overview

The LABNGOPREK enhancements provide a professional and user-friendly experience for Kubernetes cluster administrators, including custom branding, improved shell experience, and operational tools.

## 🚀 Features

### 1. **Zsh Shell with Oh-My-Zsh**
- **Default Shell**: All nodes use Zsh as the default shell for the root user
- **Oh-My-Zsh**: Pre-configured with the default theme and plugins
- **Auto-completion**: Kubectl command completion enabled
- **Cross-Platform**: Works on both Debian/Ubuntu and CentOS/RHEL systems

### 2. **LABNGOPREK Branding**
- **ASCII Banner**: Custom LABNGOPREK banner using Figlet
- **Welcome Message**: Professional MOTD with cluster information
- **System Information**: Node details, OS info, and kernel version
- **Quick Reference**: Common kubectl commands and shortcuts

### 3. **kubectl Alias and Tools**
- **Alias**: `k` alias for `kubectl` commands
- **Completion**: Full kubectl tab completion in Zsh
- **Metrics Server**: Installed for resource monitoring
- **Node/Pod Metrics**: `kubectl top nodes` and `kubectl top pods` support

### 4. **Master Node Configuration**
- **Pod Scheduling**: Master nodes can run workload pods (taint removed)
- **Resource Monitoring**: Full metrics collection on master nodes
- **Development Friendly**: Single-node clusters can run all workloads

## 📋 What Gets Installed

### System Packages
```bash
# Debian/Ubuntu
apt install zsh git figlet

# CentOS/RHEL
yum install epel-release
yum install zsh git figlet
```

### Oh-My-Zsh Configuration
- Repository: `https://github.com/ohmyzsh/ohmyzsh.git`
- Installation path: `/root/.oh-my-zsh`
- Configuration: `/root/.zshrc`

### Kubernetes Tools
- **Metrics Server**: Latest version from official repository
- **kubectl alias**: Added to `.zshrc`
- **Tab completion**: Enabled for kubectl commands

## 🔧 Configuration Details

### MOTD Banner Example
```
 _        _    ____  _   _  ____  ___  ____  _____ _  __
| |      / \  | __ )| \ | |/ ___|/ _ \|  _ \| ____| |/ /
| |     / _ \ |  _ \|  \| | |  _| | | | |_) |  _| | ' / 
| |___ / ___ \| |_) | |\  | |_| | |_| |  __/| |___| . \ 
|_____/_/   \_\____/|_| \_|\____|\___/|_|   |_____|_|\_\

Welcome to LABNGOPREK Kubernetes Cluster!
Node: kube-master01-abc123
OS: Ubuntu 22.04
Kernel: 5.15.0-86-generic

Kubernetes Commands:
• k get nodes        (alias for kubectl get nodes)
• k get pods -A      (get all pods)
• k top nodes        (node resource usage)
• k top pods -A      (pod resource usage)

Cluster Information:
• Master Nodes: 1
• Worker Nodes: 2
• CNI Plugin: cilium
```

### Zsh Configuration
```bash
# Default .zshrc additions
alias k=kubectl
source <(kubectl completion zsh)
```

### Master Node Taint Removal
```bash
kubectl taint nodes <master-node> node-role.kubernetes.io/control-plane:NoSchedule-
```

## 🎮 Usage Examples

### Quick Commands
```bash
# Instead of kubectl, use k
k get nodes
k get pods -A
k describe pod <pod-name>

# Resource monitoring
k top nodes
k top pods --all-namespaces
```

### Development on Single Node
```bash
# Deploy to master node (now possible)
k apply -f deployment.yaml

# Check workloads on master
k get pods -o wide --field-selector=spec.nodeName=<master-node>
```

## 🔄 Deployment Integration

### Automatic Application
These enhancements are automatically applied during:
1. **Standard Deployment**: After main cluster setup
2. **Parallel Deployment**: As Phase 6 of the deployment process

### Manual Application
To apply enhancements to existing clusters:
```bash
cd /root/coder/iac-provision/ansible
ansible-playbook -i inventory.py playbooks/k8s-cluster-enhancements.yml
```

## 🐛 Troubleshooting

### Common Issues

**1. Zsh not loading**
```bash
# Check default shell
echo $SHELL
# Should show /usr/bin/zsh or /bin/zsh

# If not, manually change
chsh -s /usr/bin/zsh root
```

**2. kubectl alias not working**
```bash
# Reload shell configuration
source ~/.zshrc

# Or start new shell session
exec zsh
```

**3. Metrics server not ready**
```bash
# Check metrics server status
kubectl get pods -n kube-system | grep metrics-server

# Wait for pod to be ready (may take 2-3 minutes)
kubectl wait --for=condition=ready pod -l k8s-app=metrics-server -n kube-system --timeout=300s
```

**4. Master node still has taint**
```bash
# Check current taints
kubectl describe node <master-node> | grep Taints

# Remove taint manually if needed
kubectl taint nodes <master-node> node-role.kubernetes.io/control-plane:NoSchedule-
```

## 📈 Performance Impact

- **Minimal**: Enhancements add ~30-60 seconds to deployment time
- **Memory**: Oh-My-Zsh uses ~10-20MB additional memory
- **Storage**: Additional packages require ~50-100MB disk space
- **Network**: One-time download of packages and repositories

## 🔐 Security Considerations

- **Shell Access**: Enhancements only affect root user shell experience
- **Network Policies**: Metrics server requires cluster network access
- **RBAC**: Metrics server uses standard Kubernetes RBAC permissions
- **Package Sources**: All packages from official repositories (GitHub, apt/yum)

## 🔄 Updates and Maintenance

### Updating Oh-My-Zsh
```bash
cd ~/.oh-my-zsh
git pull origin master
```

### Updating Metrics Server
```bash
kubectl apply -f https://github.com/kubernetes-sigs/metrics-server/releases/latest/download/components.yaml
```

## 📚 References

- [Oh-My-Zsh Documentation](https://github.com/ohmyzsh/ohmyzsh)
- [Kubernetes Metrics Server](https://github.com/kubernetes-sigs/metrics-server)
- [kubectl Cheat Sheet](https://kubernetes.io/docs/reference/kubectl/cheatsheet/)
- [LABNGOPREK Documentation](../README.md)

---

*This enhancement suite is designed to provide a professional and efficient Kubernetes management experience while maintaining the LABNGOPREK brand identity.*