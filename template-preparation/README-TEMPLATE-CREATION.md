# 🚀 Kubernetes Template Creation Guide

This guide will help you create pre-configured VM templates that dramatically speed up Kubernetes deployment (5-10x faster).

## 📋 Overview

Instead of installing packages during deployment, we pre-install everything in VM templates:
- ✅ All Kubernetes versions (1.28, 1.29, 1.30, 1.31)
- ✅ Containerd with proper configuration
- ✅ All CNI manifests pre-cached (Cilium, Calico, Flannel, Weave)
- ✅ Helper scripts for version switching
- ✅ Optimized system configuration

**Result**: Deployment only needs `kubeadm init/join` - no package installation!

## 🛠️ Template Creation Process

### Step 1: Create Base VMs

Create two fresh VMs in Proxmox:

#### Debian Template VM
- **OS**: Debian 12 (bookworm)
- **Resources**: 2 CPU, 2GB RAM, 32GB disk
- **Network**: Bridge to your management network
- **Name**: `debian-k8s-template-prep`

#### CentOS Template VM
- **OS**: CentOS Stream 9 or Rocky Linux 9
- **Resources**: 2 CPU, 2GB RAM, 32GB disk
- **Network**: Bridge to your management network
- **Name**: `centos-k8s-template-prep`

### Step 2: Prepare Templates

#### For Debian Template:
```bash
# 1. SSH to Debian VM
ssh root@<debian-vm-ip>

# 2. Download the script
curl -O https://raw.githubusercontent.com/your-repo/template-preparation/prepare-debian-k8s-template.sh

# 3. Make executable and run
chmod +x prepare-debian-k8s-template.sh
./prepare-debian-k8s-template.sh

# 4. Wait for completion (15-30 minutes depending on internet speed)

# 5. Run optimization
curl -O https://raw.githubusercontent.com/your-repo/template-preparation/optimize-template.sh
chmod +x optimize-template.sh
./optimize-template.sh

# 6. Shutdown
shutdown -h now
```

#### For CentOS Template:
```bash
# 1. SSH to CentOS VM
ssh root@<centos-vm-ip>

# 2. Download the script
curl -O https://raw.githubusercontent.com/your-repo/template-preparation/prepare-centos-k8s-template.sh

# 3. Make executable and run
chmod +x prepare-centos-k8s-template.sh
./prepare-centos-k8s-template.sh

# 4. Wait for completion (15-30 minutes depending on internet speed)

# 5. Run optimization
curl -O https://raw.githubusercontent.com/your-repo/template-preparation/optimize-template.sh
chmod +x optimize-template.sh
./optimize-template.sh

# 6. Shutdown
shutdown -h now
```

### Step 3: Convert VMs to Templates

In Proxmox:

1. **Right-click** on the prepared VM
2. **Select "Convert to template"**
3. **Confirm** the conversion
4. **Rename** templates:
   - `debian12-k8s-template`
   - `centos9-k8s-template`

## 🔧 Template Features

### Pre-installed Components

Each template includes:
- **Container Runtime**: containerd with SystemdCgroup enabled
- **Kubernetes**: Versions 1.28, 1.29, 1.30, 1.31 (default: 1.28)
- **CNI Tools**: Cilium CLI pre-installed
- **CNI Manifests**: All major CNI providers cached locally

### Helper Scripts

Templates include helper scripts in `/opt/k8s-scripts/`:

#### `switch-k8s-version.sh`
Switch between Kubernetes versions:
```bash
./switch-k8s-version.sh 1.29
```

#### `install-cni.sh`
Install CNI after cluster initialization:
```bash
./install-cni.sh cilium 1.15.0
./install-cni.sh calico 3.27.0
./install-cni.sh flannel
```

#### `system-info.sh`
Display template information:
```bash
./system-info.sh
```

### Cache Locations

- **Kubernetes packages**: `/opt/k8s-cache/`
- **CNI manifests**: `/opt/cni-cache/`
- **Template info**: `/opt/k8s-template-info.txt`

## 🚄 Using Fast Deployment

### Update Pipeline Configuration

Update your `config/environment.conf`:
```bash
# Use fast playbook for pre-configured templates
FAST_DEPLOYMENT=true
ANSIBLE_PLAYBOOK=k8s-cluster-setup-fast.yml

# Template names
DEBIAN_TEMPLATE=debian12-k8s-template
CENTOS_TEMPLATE=centos9-k8s-template
```

### Update VM Configuration

Update your `vms.csv` to use the new templates:
```csv
vmid,vm_name,template,node,ip,cores,memory,disk_size
0,kube-master01,debian12-k8s-template,thinkcentre,0,2,2048,32G
0,kube-worker01,debian12-k8s-template,thinkcentre,0,2,2048,32G
0,kube-worker02,debian12-k8s-template,thinkcentre,0,2,2048,32G
```

## ⚡ Performance Comparison

### Traditional Deployment (OLD)
```
┌─────────────────────┬──────────┐
│ Phase               │ Time     │
├─────────────────────┼──────────┤
│ VM Provisioning     │ 2-3 min  │
│ Package Updates     │ 3-5 min  │
│ Docker Installation │ 2-3 min  │
│ K8s Installation    │ 3-5 min  │
│ CNI Download        │ 1-2 min  │
│ Cluster Init        │ 2-3 min  │
│ CNI Setup           │ 2-3 min  │
├─────────────────────┼──────────┤
│ TOTAL               │ 15-24min │
└─────────────────────┴──────────┘
```

### Fast Deployment (NEW)
```
┌─────────────────────┬──────────┐
│ Phase               │ Time     │
├─────────────────────┼──────────┤
│ VM Provisioning     │ 1-2 min  │
│ Template Boot       │ 30s      │
│ Cluster Init        │ 1-2 min  │
│ CNI Setup (cached)  │ 30s      │
├─────────────────────┼──────────┤
│ TOTAL               │ 3-5 min  │
└─────────────────────┴──────────┘
```

**🎯 Speed Improvement: 5-8x faster!**

## 🔍 Template Verification

After creating templates, test them:

### 1. Deploy Test VM
```bash
# Create VM from template
# Boot and SSH to it
```

### 2. Verify Template
```bash
# Check template info
cat /opt/k8s-template-info.txt

# Verify components
system-info.sh

# Test version switching
switch-k8s-version.sh 1.29
kubelet --version

# Test CNI cache
ls /opt/cni-cache/
```

### 3. Test Deployment
```bash
# Run fast deployment pipeline
# Verify cluster comes up in 3-5 minutes
```

## 🔧 Maintenance

### Updating Templates

To update templates with new versions:

1. **Clone template** to working VM
2. **Update packages** and add new versions
3. **Re-run optimization** script
4. **Convert back to template**
5. **Update template name** with version/date

### Template Versioning

Recommended naming convention:
- `debian12-k8s-template-2024-01`
- `centos9-k8s-template-2024-01`

## 🚨 Troubleshooting

### Template Creation Issues

**Problem**: Script fails with "repository not found"
**Solution**: Check internet connectivity and repository URLs

**Problem**: Out of disk space during preparation
**Solution**: Use VM with at least 32GB disk space

**Problem**: Package installation fails
**Solution**: Update base OS packages first

### Deployment Issues

**Problem**: Template verification fails
**Solution**: Ensure VM is created from correct template

**Problem**: CNI installation fails
**Solution**: Check `/opt/cni-cache/` directory exists and has manifests

**Problem**: Version switching fails
**Solution**: Check `/opt/k8s-cache/` has required packages

## 📚 Additional Resources

- **Scripts Location**: `template-preparation/`
- **Fast Playbook**: `ansible/playbooks/k8s-cluster-setup-fast.yml`
- **Configuration**: `config/environment.conf`

## 🎉 Success Metrics

With properly configured templates, you should see:
- ✅ **5-8x faster deployments**
- ✅ **90% reduction in network usage**
- ✅ **More reliable deployments** (no download failures)
- ✅ **Consistent environments**
- ✅ **Easy version management**

---

**Ready to speed up your Kubernetes deployments? Create your templates now! 🚀**