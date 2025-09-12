#!/bin/bash
# Simple ZSH Installation for ULTRA Templates - Based on k8s-cluster-enhancements.yml
# This matches exactly what the enhancement playbook does

set -e

echo "🔧 SIMPLE ZSH INSTALLATION (like enhancement playbook)"
echo "===================================================="

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[$(date +'%H:%M:%S')] $1${NC}"
}

# Phase 1: Install ZSH based on OS
log "Installing ZSH and dependencies..."

if command -v apt-get >/dev/null 2>&1; then
    log "Installing on Debian/Ubuntu..."
    apt-get update -qq
    apt-get install -y zsh git figlet >/dev/null 2>&1
elif command -v dnf >/dev/null 2>&1; then
    log "Installing on CentOS 9..."
    dnf install -y epel-release >/dev/null 2>&1
    dnf install -y zsh git figlet >/dev/null 2>&1
elif command -v yum >/dev/null 2>&1; then
    log "Installing on legacy CentOS/RHEL..."
    yum install -y epel-release >/dev/null 2>&1
    yum install -y zsh git figlet >/dev/null 2>&1
fi

# Phase 2: Change default shell
log "Changing default shell to ZSH..."
if [ -f "/usr/bin/zsh" ]; then
    chsh -s /usr/bin/zsh root
elif [ -f "/bin/zsh" ]; then
    chsh -s /bin/zsh root
fi

# Phase 3: Install Oh My Zsh (simple, like playbook)
log "Installing Oh My Zsh..."
if [ ! -d ~/.oh-my-zsh ]; then
    git clone https://github.com/ohmyzsh/ohmyzsh.git ~/.oh-my-zsh >/dev/null 2>&1
    cp ~/.oh-my-zsh/templates/zshrc.zsh-template ~/.zshrc
fi

# Phase 4: Simple .zshrc configuration (EXACTLY like playbook)
log "Configuring .zshrc (simple like playbook)..."
cat > ~/.zshrc << 'EOF'
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="robbyrussell"

plugins=(git)

source $ZSH/oh-my-zsh.sh

# Simple kubectl alias (like enhancement playbook)
alias k=kubectl

# Kubectl completion
source <(kubectl completion zsh)

echo "LABNGOPREK Kubernetes environment ready!"
EOF

# Phase 5: Generate MOTD with figlet (like playbook)
log "Creating LABNGOPREK MOTD with figlet..."
BANNER=$(figlet LABNGOPREK)

# Detect OS for MOTD path
if command -v dnf >/dev/null 2>&1 || command -v yum >/dev/null 2>&1; then
    # CentOS/RedHat
    mkdir -p /etc/motd.d
    MOTD_PATH="/etc/motd.d/cockpit"
    OS_INFO="CentOS Stream 9"
else
    # Debian
    MOTD_PATH="/etc/motd"
    OS_INFO="Debian 12"
fi

cat > "$MOTD_PATH" << EOF
$BANNER

Welcome to LABNGOPREK Kubernetes Cluster!
Node: \$(hostname)
OS: $OS_INFO
Kernel: \$(uname -r)

Kubernetes Commands:
• k get nodes        (alias for kubectl get nodes)
• k get pods -A      (get all pods)
• k top nodes        (node resource usage)
• k top pods -A      (pod resource usage)

ULTRA Template Features:
• 25-30 second deployment time
• Pre-pulled container images
• Pre-installed CLI tools
• Simple ZSH with kubectl aliases

EOF

echo ""
echo "✅ SIMPLE ZSH INSTALLATION COMPLETE!"
echo ""
echo "📋 What was installed:"
echo "  • ZSH with robbyrussell theme"
echo "  • Oh My Zsh (basic)"
echo "  • kubectl alias (k=kubectl)"  
echo "  • kubectl completion"
echo "  • LABNGOPREK MOTD with figlet"
echo ""
echo "🎯 This matches EXACTLY what k8s-cluster-enhancements.yml does"
echo "   No need for ZSH installation in playbooks anymore!"

log "Simple ZSH template configuration completed!"