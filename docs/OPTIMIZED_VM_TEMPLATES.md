# 🚀 OPTIMIZED VM TEMPLATES FOR KUBERNETES DEPLOYMENT

## 📋 **ANALISIS CURRENT DEPLOYMENT PHASES**

Berdasarkan analisis Jenkins build #315 dan #317, berikut breakdown fase deployment:

### ⏱️ **Current Phase Timings:**
```
Phase 1 (System Prep):        11-13s
Phase 2 (Container Runtime):  34-35s  
Phase 3 (K8s Packages):       17-18s
Phase 4 (Cluster Init):       42-58s
Phase 5 (CNI Installation):   47-66s
TOTAL:                         167-174s (2m47s - 2m54s)
```

---

## 🎯 **TEMPLATE OPTIMIZATION STRATEGY**

**💡 KONSEP:** Pre-install semua yang **STATIS** di template, jalankan hanya yang **DINAMIS** saat provisioning.

### 📦 **WHAT CAN BE PRE-BAKED INTO TEMPLATES:**

#### **✅ PHASE 1 - SYSTEM PREPARATION (100% dapat di-prebake)**
```bash
# Kernel modules & sysctl
- overlay, br_netfilter modules loaded
- /etc/modules-load.d/k8s.conf configured
- /etc/sysctl.d/k8s.conf applied
- SELinux disabled (CentOS)
- Swap disabled permanently (/etc/fstab)

# Performance optimizations
- net.bridge.bridge-nf-call-iptables=1
- net.ipv4.ip_forward=1
- vm.max_map_count=262144
```

#### **✅ PHASE 2 - CONTAINER RUNTIME (90% dapat di-prebake)**
```bash
# Repository & prerequisites
- Docker/containerd repositories added
- GPG keys installed
- Prerequisites packages installed

# containerd installation
- containerd.io package installed
- /etc/containerd/config.toml configured
- containerd service enabled & started
- crictl installed & configured
```

#### **✅ PHASE 3 - KUBERNETES PACKAGES (95% dapat di-prebake)**
```bash
# K8s repository & packages
- Kubernetes APT/YUM repository added
- kubelet, kubeadm, kubectl installed
- Packages held (apt-mark hold / yum versionlock)
- kubelet service enabled (but not started)
```

#### **✅ PHASE 4 - IMAGE PRE-PULLING (80% dapat di-prebake)**
```bash
# Kubernetes images
- registry.k8s.io/kube-apiserver:v1.32.7
- registry.k8s.io/kube-controller-manager:v1.32.7  
- registry.k8s.io/kube-scheduler:v1.32.7
- registry.k8s.io/kube-proxy:v1.32.7
- registry.k8s.io/coredns/coredns:v1.11.3
- registry.k8s.io/pause:3.10
- registry.k8s.io/etcd:3.5.16-0

# CNI images (Cilium)
- quay.io/cilium/cilium:v1.16.0
- quay.io/cilium/operator-generic:v1.16.0
```

---

## 📋 **VM TEMPLATE SPECIFICATIONS**

### 🐧 **DEBIAN 12 KUBERNETES-READY TEMPLATE**

#### **Template Name:** `t-debian12-k8s-ready`

#### **Pre-installed Components:**
```bash
# Base System
- Debian 12 (bookworm) minimal
- openssh-server, curl, wget, vim, htop
- ca-certificates, apt-transport-https, gnupg, lsb-release

# Kubernetes Prerequisites  
- Docker APT repository configured
- Kubernetes APT repository configured
- containerd.io installed & configured
- kubelet, kubeadm, kubectl installed (held)
- crictl installed & configured

# System Configuration
- Swap disabled permanently
- Required kernel modules loaded
- Kubernetes sysctl parameters applied
- containerd systemd service enabled

# Pre-pulled Images
- All Kubernetes v1.32.7 control plane images
- Cilium CNI v1.16.0 images  
- Common utility images (busybox, alpine, etc.)

# Network Configuration
- UFW disabled
- Required ports pre-configured
- DNS resolution optimized
```

#### **Template Creation Script:**
```bash
#!/bin/bash
# Debian 12 K8s Template Creation Script

# 1. Basic system setup
apt update && apt upgrade -y
apt install -y openssh-server curl wget vim htop ca-certificates apt-transport-https gnupg lsb-release

# 2. Disable swap permanently  
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 3. Load kernel modules
modprobe overlay br_netfilter
cat > /etc/modules-load.d/k8s.conf << EOF
overlay
br_netfilter
EOF

# 4. Apply sysctl parameters
cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1
net.ipv4.ip_forward=1
net.netfilter.nf_conntrack_max=1000000
net.core.somaxconn=32768
vm.max_map_count=262144
EOF
sysctl --system

# 5. Install Docker repository
mkdir -p /usr/share/keyrings
curl -fsSL https://download.docker.com/linux/debian/gpg | gpg --dearmor -o /usr/share/keyrings/docker-archive-keyring.gpg
echo "deb [arch=amd64 signed-by=/usr/share/keyrings/docker-archive-keyring.gpg] https://download.docker.com/linux/debian bookworm stable" > /etc/apt/sources.list.d/docker.list

# 6. Install Kubernetes repository
curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.32/deb/Release.key | gpg --dearmor -o /usr/share/keyrings/kubernetes-archive-keyring.gpg
echo "deb [signed-by=/usr/share/keyrings/kubernetes-archive-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.32/deb/ /" > /etc/apt/sources.list.d/kubernetes.list

# 7. Install packages
apt update
apt install -y containerd.io kubelet kubeadm kubectl

# 8. Hold packages
apt-mark hold kubelet kubeadm kubectl containerd.io

# 9. Configure containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl enable containerd
systemctl start containerd

# 10. Install crictl
curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.32.0/crictl-v1.32.0-linux-amd64.tar.gz" | tar -C /usr/local/bin -xz
chmod +x /usr/local/bin/crictl
cat > /etc/crictl.yaml << EOF
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
timeout: 5
debug: false
EOF

# 11. Pre-pull Kubernetes images
kubeadm config images pull --kubernetes-version=v1.32.7

# 12. Pre-pull CNI images
ctr images pull quay.io/cilium/cilium:v1.16.0
ctr images pull quay.io/cilium/operator-generic:v1.16.0

# 13. Enable kubelet (but don't start - will be started by kubeadm)
systemctl enable kubelet

# 14. Clean up
apt autoremove -y
apt autoclean
rm -rf /tmp/* /var/tmp/*
history -c

# 15. Template finalization
echo "✅ Debian 12 Kubernetes-ready template prepared!"
```

---

### 🔴 **CENTOS 9 KUBERNETES-READY TEMPLATE**

#### **Template Name:** `t-centos9-k8s-ready`

#### **Pre-installed Components:**
```bash
# Base System
- CentOS Stream 9 minimal
- openssh-server, curl, wget, vim, htop
- yum-utils, device-mapper-persistent-data, lvm2

# Kubernetes Prerequisites
- Docker YUM repository configured  
- Kubernetes YUM repository configured
- containerd.io installed & configured
- kubelet, kubeadm, kubectl installed (version locked)
- crictl installed & configured

# System Configuration
- SELinux disabled permanently
- Swap disabled permanently  
- Required kernel modules loaded
- Kubernetes sysctl parameters applied
- containerd systemd service enabled
- Firewalld configured for K8s ports

# Pre-pulled Images
- All Kubernetes v1.32.7 control plane images
- Cilium CNI v1.16.0 images
- Common utility images
```

#### **Template Creation Script:**
```bash
#!/bin/bash
# CentOS 9 K8s Template Creation Script

# 1. Basic system setup
dnf update -y
dnf install -y openssh-server curl wget vim htop yum-utils device-mapper-persistent-data lvm2

# 2. Disable SELinux permanently
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config

# 3. Disable swap permanently
swapoff -a  
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab

# 4. Configure firewall
systemctl disable firewalld --now

# 5. Load kernel modules
modprobe overlay br_netfilter
cat > /etc/modules-load.d/k8s.conf << EOF
overlay
br_netfilter
EOF

# 6. Apply sysctl parameters  
cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-iptables=1
net.bridge.bridge-nf-call-ip6tables=1  
net.ipv4.ip_forward=1
net.netfilter.nf_conntrack_max=1000000
net.core.somaxconn=32768
vm.max_map_count=262144
EOF
sysctl --system

# 7. Add Docker repository
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# 8. Add Kubernetes repository  
cat > /etc/yum.repos.d/kubernetes.repo << EOF
[kubernetes]
name=Kubernetes
baseurl=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v1.32/rpm/repodata/repomd.xml.key
EOF

# 9. Install packages
dnf install -y containerd.io kubelet kubeadm kubectl

# 10. Lock package versions
yum versionlock kubelet kubeadm kubectl containerd.io

# 11. Configure containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml
systemctl enable containerd
systemctl start containerd

# 12. Install crictl
curl -L "https://github.com/kubernetes-sigs/cri-tools/releases/download/v1.32.0/crictl-v1.32.0-linux-amd64.tar.gz" | tar -C /usr/local/bin -xz
chmod +x /usr/local/bin/crictl  
cat > /etc/crictl.yaml << EOF
runtime-endpoint: unix:///var/run/containerd/containerd.sock
image-endpoint: unix:///var/run/containerd/containerd.sock
timeout: 5
debug: false
EOF

# 13. Pre-pull Kubernetes images
kubeadm config images pull --kubernetes-version=v1.32.7

# 14. Pre-pull CNI images
ctr images pull quay.io/cilium/cilium:v1.16.0
ctr images pull quay.io/cilium/operator-generic:v1.16.0  

# 15. Enable kubelet
systemctl enable kubelet

# 16. Clean up
dnf autoremove -y
dnf clean all
rm -rf /tmp/* /var/tmp/*
history -c

echo "✅ CentOS 9 Kubernetes-ready template prepared!"
```

---

## ⚡ **OPTIMIZED DEPLOYMENT PHASES**

### 🚀 **NEW ULTRA-FAST DEPLOYMENT FLOW:**

With pre-baked templates, deployment phases become:

#### **Phase 1: Template Validation (5s)**
```yaml
- Verify template is K8s-ready
- Check pre-installed components
- Validate system configuration
```

#### **Phase 2: Dynamic Configuration (10s)**  
```yaml
- Set hostnames
- Configure cluster-specific networking
- Apply node-specific labels/taints
```

#### **Phase 3: Cluster Initialization (15s)**
```yaml
- kubeadm init (images already pulled!)
- Copy admin.conf
- Generate join tokens
```

#### **Phase 4: Node Joining (10s)**
```yaml  
- Join worker nodes (parallel)
- Apply node labels
```

#### **Phase 5: CNI Deployment (10s)**
```yaml
- Deploy Cilium (images already pulled!)  
- Wait for pods ready
- Verify cluster networking
```

### 📊 **ESTIMATED NEW PERFORMANCE:**
```
OLD: 167-174s (2m47s - 2m54s)
NEW: ~50s (0m50s)
IMPROVEMENT: 3.5x FASTER! 🚀
```

---

## 🛠️ **PROXMOX TEMPLATE CREATION GUIDE**

### 1️⃣ **Create Base VM**
```bash
# Create VM in Proxmox
qm create 9001 --name "debian12-k8s-template" --memory 2048 --cores 2 --net0 virtio,bridge=vmbr0
qm importdisk 9001 debian-12-generic-amd64.qcow2 local-lvm
qm set 9001 --scsihw virtio-scsi-pci --scsi0 local-lvm:vm-9001-disk-0
qm set 9001 --boot c --bootdisk scsi0
qm set 9001 --ide2 local-lvm:cloudinit
qm set 9001 --serial0 socket --vga serial0
```

### 2️⃣ **Install & Configure**
```bash
# Start VM and run template creation script
qm start 9001
# SSH into VM and run the Debian/CentOS template script above
```

### 3️⃣ **Convert to Template**
```bash  
# Shutdown VM cleanly
qm shutdown 9001

# Convert to template
qm template 9001

# Clone for use
qm clone 9001 101 --name "k8s-master-01"
```

---

## 🔧 **MODIFIED ANSIBLE PLAYBOOKS**

Templates akan menggunakan **conditional skipping** untuk pre-installed components:

```yaml
# Skip if template is k8s-ready
- name: Install containerd
  apt:
    name: containerd.io
    state: present
  when: not (template_type | default('') == 'k8s-ready')

# Only run dynamic parts
- name: Configure cluster-specific networking
  template:
    src: cluster-network.conf.j2
    dest: /etc/kubernetes/cluster-network.conf
  when: cluster_config is defined
```

---

## 🎯 **BENEFITS OF PRE-BAKED TEMPLATES**

### ✅ **Performance Benefits:**
- **3.5x faster deployment** (174s → 50s)
- **No network dependencies** during provisioning
- **Parallel cluster creation** without package conflicts
- **Predictable deployment times**

### ✅ **Operational Benefits:**
- **Consistent environments** across all deployments
- **Version-locked components** prevent drift
- **Faster disaster recovery** 
- **Reduced Jenkins job complexity**

### ✅ **Resource Benefits:**
- **Lower bandwidth usage** during provisioning  
- **Reduced Proxmox storage** (deduplication)
- **Better resource utilization**
- **Cached images** reduce registry load

---

## 🚀 **IMPLEMENTATION ROADMAP**

1. **Create Debian 12 template** (t-debian12-k8s-ready)
2. **Create CentOS 9 template** (t-centos9-k8s-ready)  
3. **Modify Jenkins pipeline** to use pre-baked templates
4. **Update Ansible playbooks** with conditional logic
5. **Test deployment performance** 
6. **Document template maintenance** procedures

**Target Result: 2m54s → 50s deployment time! 🔥**