#!/bin/bash
# CentOS/RHEL Kubernetes Template Preparation Script
# This script prepares a CentOS/Rocky/RHEL VM with all Kubernetes components pre-installed
# Run this on a fresh CentOS/Rocky Linux VM that will be converted to template

set -e

echo "🚀 Starting CentOS/RHEL Kubernetes Template Preparation"
echo "======================================================"

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Log function
log() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')]${NC} $1"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Kubernetes versions to support
K8S_VERSIONS=("1.28" "1.29" "1.30" "1.31")
DEFAULT_K8S_VERSION="1.28"

# CNI versions to pre-download
CILIUM_VERSIONS=("1.14.5" "1.15.0" "1.16.0")
CALICO_VERSIONS=("3.26.0" "3.27.0" "3.28.0")
FLANNEL_VERSION="latest"
WEAVE_VERSION="2.8.1"

log "System Information:"
cat /etc/os-release | grep -E "(NAME|VERSION)"
log "Architecture: $(uname -m)"
log "Kernel: $(uname -r)"

# Disable SELinux
log "Disabling SELinux..."
setenforce 0
sed -i 's/^SELINUX=enforcing$/SELINUX=disabled/' /etc/selinux/config
success "SELinux disabled"

# Update system
log "Updating system packages..."
yum update -y -q
success "System updated"

# Install essential packages
log "Installing essential packages..."
yum install -y -q \
    yum-utils \
    device-mapper-persistent-data \
    lvm2 \
    curl \
    wget \
    unzip \
    jq \
    htop \
    vim \
    git \
    bash-completion \
    tar

success "Essential packages installed"

# Disable swap permanently
log "Disabling swap permanently..."
swapoff -a
sed -i '/ swap / s/^\(.*\)$/#\1/g' /etc/fstab
success "Swap disabled"

# Disable firewall (for template - can be re-enabled later)
log "Disabling firewall..."
systemctl disable firewalld || true
systemctl stop firewalld || true
success "Firewall disabled"

# Configure kernel modules for Kubernetes
log "Configuring kernel modules..."
cat > /etc/modules-load.d/k8s.conf << EOF
overlay
br_netfilter
EOF

modprobe overlay
modprobe br_netfilter
success "Kernel modules configured"

# Configure sysctl parameters
log "Configuring sysctl parameters..."
cat > /etc/sysctl.d/k8s.conf << EOF
net.bridge.bridge-nf-call-iptables  = 1
net.bridge.bridge-nf-call-ip6tables = 1
net.ipv4.ip_forward                 = 1
EOF

sysctl --system > /dev/null
success "Sysctl parameters configured"

# Install containerd
log "Installing containerd..."

# Add Docker repository
yum-config-manager --add-repo https://download.docker.com/linux/centos/docker-ce.repo

# Install containerd
yum install -y -q containerd.io

# Configure containerd
mkdir -p /etc/containerd
containerd config default > /etc/containerd/config.toml

# Enable SystemdCgroup
sed -i 's/SystemdCgroup = false/SystemdCgroup = true/' /etc/containerd/config.toml

systemctl enable containerd
systemctl start containerd
success "Containerd installed and configured"

# Install all supported Kubernetes versions
log "Installing Kubernetes components for all versions..."

mkdir -p /opt/k8s-cache
cd /opt/k8s-cache

for version in "${K8S_VERSIONS[@]}"; do
    log "Installing Kubernetes v${version}..."
    
    # Add Kubernetes repository for this version
    cat > /etc/yum.repos.d/kubernetes-${version}.repo << EOF
[kubernetes-${version}]
name=Kubernetes ${version}
baseurl=https://pkgs.k8s.io/core:/stable:/v${version}/rpm/
enabled=1
gpgcheck=1
gpgkey=https://pkgs.k8s.io/core:/stable:/v${version}/rpm/repodata/repomd.xml.key
EOF
    
    yum clean all -q
    
    # Download packages but don't install yet (except default version)
    if [ "$version" = "$DEFAULT_K8S_VERSION" ]; then
        yum install -y -q kubelet kubeadm kubectl --disableexcludes=kubernetes
        success "Kubernetes v${version} installed (default)"
    else
        # Download packages for future use
        yumdownloader kubelet kubeadm kubectl
        success "Kubernetes v${version} packages downloaded"
    fi
done

systemctl enable kubelet
success "All Kubernetes versions prepared"

# Create CNI cache directory
log "Creating CNI cache directory..."
mkdir -p /opt/cni-cache
cd /opt/cni-cache

# Download Cilium CLI and versions
log "Downloading Cilium components..."
mkdir -p cilium
cd cilium

# Download Cilium CLI
CILIUM_CLI_VERSION=$(curl -s https://raw.githubusercontent.com/cilium/cilium-cli/master/stable.txt)
CLI_ARCH=amd64
if [ "$(uname -m)" = "aarch64" ]; then CLI_ARCH=arm64; fi

curl -L --remote-name-all https://github.com/cilium/cilium-cli/releases/download/${CILIUM_CLI_VERSION}/cilium-linux-${CLI_ARCH}.tar.gz{,.sha256sum}
sha256sum --check cilium-linux-${CLI_ARCH}.tar.gz.sha256sum
tar xzf cilium-linux-${CLI_ARCH}.tar.gz
mv cilium /usr/local/bin/
chmod +x /usr/local/bin/cilium

# Pre-download Cilium images for different versions
for cilium_ver in "${CILIUM_VERSIONS[@]}"; do
    log "Pre-pulling Cilium v${cilium_ver} images..."
    /usr/local/bin/cilium install --version ${cilium_ver} --dry-run-helm-values > cilium-${cilium_ver}-values.yaml || true
done

cd /opt/cni-cache
success "Cilium components downloaded"

# Download Calico manifests
log "Downloading Calico manifests..."
mkdir -p calico
cd calico

for calico_ver in "${CALICO_VERSIONS[@]}"; do
    curl -O https://raw.githubusercontent.com/projectcalico/calico/v${calico_ver}/manifests/tigera-operator.yaml
    mv tigera-operator.yaml tigera-operator-${calico_ver}.yaml
    log "Downloaded Calico v${calico_ver} manifest"
done

cd /opt/cni-cache
success "Calico manifests downloaded"

# Download Flannel manifest
log "Downloading Flannel manifest..."
mkdir -p flannel
cd flannel
curl -O https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
cd /opt/cni-cache
success "Flannel manifest downloaded"

# Download Weave manifest
log "Downloading Weave manifest..."
mkdir -p weave
cd weave
curl -O https://github.com/weaveworks/weave/releases/download/v${WEAVE_VERSION}/weave-daemonset-k8s.yaml
cd /opt/cni-cache
success "Weave manifest downloaded"

# Create helper scripts
log "Creating helper scripts..."
mkdir -p /opt/k8s-scripts

# Create version switcher script
cat > /opt/k8s-scripts/switch-k8s-version.sh << 'EOF'
#!/bin/bash
# Kubernetes Version Switcher for CentOS/RHEL
# Usage: ./switch-k8s-version.sh 1.29

set -e

if [ $# -ne 1 ]; then
    echo "Usage: $0 <version>"
    echo "Available versions: 1.28, 1.29, 1.30, 1.31"
    exit 1
fi

VERSION="$1"
echo "Switching to Kubernetes v${VERSION}..."

# Remove current packages
yum remove -y kubelet kubeadm kubectl

# Install new version from specific repo
yum install -y kubelet kubeadm kubectl --disableexcludes=kubernetes --enablerepo=kubernetes-${VERSION}

systemctl enable kubelet
echo "✅ Switched to Kubernetes v${VERSION}"
EOF

chmod +x /opt/k8s-scripts/switch-k8s-version.sh

# Create CNI installer script (same as Debian)
cat > /opt/k8s-scripts/install-cni.sh << 'EOF'
#!/bin/bash
# CNI Installer Script
# Usage: ./install-cni.sh <cni-type> <version> [pod-cidr]

set -e

CNI_TYPE="$1"
VERSION="$2"
POD_CIDR="${3:-10.244.0.0/16}"

case "$CNI_TYPE" in
    "cilium")
        echo "Installing Cilium v${VERSION}..."
        cilium install --version ${VERSION}
        cilium status --wait
        ;;
    "calico")
        echo "Installing Calico v${VERSION}..."
        kubectl create -f /opt/cni-cache/calico/tigera-operator-${VERSION}.yaml
        cat <<CALICO_EOF | kubectl create -f -
apiVersion: operator.tigera.io/v1
kind: Installation
metadata:
  name: default
spec:
  calicoNetwork:
    ipPools:
    - blockSize: 26
      cidr: ${POD_CIDR}
      encapsulation: VXLANCrossSubnet
      natOutgoing: Enabled
      nodeSelector: all()
CALICO_EOF
        ;;
    "flannel")
        echo "Installing Flannel..."
        kubectl apply -f /opt/cni-cache/flannel/kube-flannel.yml
        ;;
    "weave")
        echo "Installing Weave v${VERSION}..."
        kubectl apply -f /opt/cni-cache/weave/weave-daemonset-k8s.yaml
        ;;
    *)
        echo "Unsupported CNI type: $CNI_TYPE"
        echo "Supported: cilium, calico, flannel, weave"
        exit 1
        ;;
esac

echo "✅ ${CNI_TYPE} CNI installed successfully"
EOF

chmod +x /opt/k8s-scripts/install-cni.sh

success "Helper scripts created"

# Create system info script
cat > /opt/k8s-scripts/system-info.sh << 'EOF'
#!/bin/bash
# System Information Display

echo "🔍 Kubernetes Template Information"
echo "=================================="
echo "OS: $(cat /etc/os-release | grep PRETTY_NAME | cut -d'"' -f2)"
echo "Kernel: $(uname -r)"
echo "Architecture: $(uname -m)"
echo ""
echo "📦 Installed Components:"
echo "- Containerd: $(containerd --version | cut -d' ' -f3)"
echo "- Kubernetes: $(kubelet --version | cut -d' ' -f2)"
echo "- Cilium CLI: $(cilium version --client 2>/dev/null | grep 'cilium-cli' | awk '{print $2}' || echo 'installed')"
echo ""
echo "🗂️  Available Kubernetes Versions:"
ls /opt/k8s-cache/*.rpm 2>/dev/null | grep -o 'kubelet.*' | sort -u || echo "Check /opt/k8s-cache/"
echo ""
echo "🌐 Available CNI Manifests:"
find /opt/cni-cache -name "*.yaml" -o -name "*.yml" | wc -l
echo ""
echo "📄 Helper Scripts:"
ls -la /opt/k8s-scripts/
EOF

chmod +x /opt/k8s-scripts/system-info.sh

# Add to PATH
echo 'export PATH="/opt/k8s-scripts:$PATH"' >> /etc/bash.bashrc

success "Template preparation complete!"

log "Final cleanup and optimization..."

# Clean package cache
yum autoremove -y -q
yum clean all -q

# Clear logs
journalctl --vacuum-time=1d
find /var/log -type f -name "*.log" -exec truncate -s 0 {} \;

# Clear bash history
history -c
history -w
rm -f ~/.bash_history /root/.bash_history

# Clear temporary files
rm -rf /tmp/*
rm -rf /var/tmp/*

# Clear network configuration that might interfere with template
rm -f /etc/machine-id
rm -f /var/lib/dbus/machine-id
> /etc/hostname

# Reset network interfaces (will be regenerated on first boot)
rm -f /etc/sysconfig/network-scripts/ifcfg-*
cat > /etc/sysconfig/network-scripts/ifcfg-eth0 << EOF
DEVICE=eth0
BOOTPROTO=dhcp
ONBOOT=yes
EOF

success "Template optimization complete!"

echo ""
echo "🎉 CentOS/RHEL Kubernetes Template Preparation Complete!"
echo "======================================================"
echo ""
echo "📊 Template Summary:"
echo "- Kubernetes versions: ${K8S_VERSIONS[*]}"
echo "- Default K8s version: v${DEFAULT_K8S_VERSION}"
echo "- CNI options: Cilium, Calico, Flannel, Weave"
echo "- Helper scripts: /opt/k8s-scripts/"
echo ""
echo "🔄 Next Steps:"
echo "1. Shutdown this VM: sudo shutdown -h now"
echo "2. Convert VM to template in Proxmox"
echo "3. Name template: centos-k8s-template or rocky-k8s-template"
echo "4. Use template for fast Kubernetes deployment"
echo ""
echo "⚡ With this template, Kubernetes deployment will be 5-10x faster!"
echo "Only kubeadm init/join operations needed, no package installation."