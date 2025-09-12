#!/bin/bash
# ULTRA Template Verification Script
# Run this script on each template VM to verify all optimizations are applied

echo "🔍 LABNGOPREK ULTRA TEMPLATE VERIFICATION"
echo "========================================"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

TOTAL_CHECKS=0
PASSED_CHECKS=0

check_item() {
    local description="$1"
    local command="$2"
    local expected="$3"
    
    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    echo -n "[$TOTAL_CHECKS] $description: "
    
    if eval "$command" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ PASS${NC}"
        PASSED_CHECKS=$((PASSED_CHECKS + 1))
        return 0
    else
        echo -e "${RED}❌ FAIL${NC}"
        if [ -n "$expected" ]; then
            echo "    Expected: $expected"
        fi
        return 1
    fi
}

check_file() {
    local description="$1"
    local filepath="$2"
    
    check_item "$description" "test -f '$filepath'"
}

check_dir() {
    local description="$1" 
    local dirpath="$2"
    
    check_item "$description" "test -d '$dirpath'"
}

check_content() {
    local description="$1"
    local filepath="$2"
    local pattern="$3"
    
    check_item "$description" "grep -q '$pattern' '$filepath'" "Contains: $pattern"
}

echo ""
echo "🎯 Phase 1: Core Template Markers"
echo "--------------------------------"
check_file "Ultra optimization marker" "/etc/kubernetes-ultra-optimized"
check_file "Base template info" "/etc/kubernetes-template-info"
check_content "Template type is ULTRA" "/etc/kubernetes-template-info" "ULTRA-OPTIMIZED"

echo ""
echo "🛠️ Phase 2: CLI Tools Installation"
echo "---------------------------------"
check_file "Cilium CLI installed" "/usr/local/bin/cilium"
check_file "Hubble CLI installed" "/usr/local/bin/hubble" 
check_file "kubectl-krew installed" "/usr/local/bin/kubectl-krew"

# Test CLI tools actually work
check_item "Cilium CLI executable" "/usr/local/bin/cilium version --client"
check_item "Hubble CLI executable" "/usr/local/bin/hubble --help"

echo ""
echo "📦 Phase 3: Pre-staged Manifests"
echo "-------------------------------"
check_dir "Kubernetes addon directory" "/opt/kubernetes/addons"
check_file "Metrics Server manifest" "/opt/kubernetes/addons/metrics-server.yaml"
check_file "MetalLB manifest" "/opt/kubernetes/addons/metallb.yaml"
check_dir "Kubernetes configs directory" "/opt/kubernetes/configs"
check_file "Cilium values template" "/opt/kubernetes/configs/cilium-values.yaml"

echo ""
echo "🐳 Phase 4: Container Images Pre-pulling"
echo "---------------------------------------"
if command -v crictl >/dev/null 2>&1; then
    IMAGE_COUNT=$(crictl images -q | wc -l)
    check_item "Container images pre-pulled (≥15)" "test $IMAGE_COUNT -ge 15" "$IMAGE_COUNT images found"
    
    # Check specific critical images
    check_item "Kubernetes core images" "crictl images | grep -q 'registry.k8s.io'"
    check_item "Cilium images pre-pulled" "crictl images | grep -q 'cilium'"
    check_item "MetalLB images pre-pulled" "crictl images | grep -q 'metallb'"
    check_item "Metrics server image" "crictl images | grep -q 'metrics-server'"
else
    echo -e "${YELLOW}⚠️  crictl not available - skipping image checks${NC}"
fi

echo ""
echo "🎨 Phase 5: LABNGOPREK Branding"
echo "-----------------------------"
check_content "LABNGOPREK MOTD banner" "/etc/motd" "LABNGOPREK"
check_content "ULTRA template MOTD info" "/etc/motd" "ULTRA-OPTIMIZED"
check_content "Kubernetes aliases in bashrc" "/root/.bashrc" "alias k="

# Check OS-specific branding
if [ -f "/etc/centos-release" ] || [ -f "/etc/redhat-release" ]; then
    check_content "CentOS specific branding" "/etc/motd" "CentOS"
    check_content "CentOS aliases in bashrc" "/root/.bashrc" "alias dnfu="
elif [ -f "/etc/debian_version" ]; then
    check_content "Debian specific info" "/etc/kubernetes-template-info" "Debian\\|Ubuntu"
fi

echo ""
echo "⚙️ Phase 6: Performance Optimizations"
echo "-----------------------------------"
check_file "Containerd config optimized" "/etc/containerd/config.toml"
check_content "Containerd performance settings" "/etc/containerd/config.toml" "max_concurrent_downloads"
check_item "Containerd service active" "systemctl is-active containerd"

# Check package cache
if command -v apt-get >/dev/null 2>&1; then
    check_item "APT cache warmed" "test -d /var/lib/apt/lists && test -n \"\$(ls -A /var/lib/apt/lists)\""
elif command -v dnf >/dev/null 2>&1; then
    check_item "DNF cache warmed" "test -d /var/cache/dnf && test -n \"\$(ls -A /var/cache/dnf)\""
fi

echo ""
echo "🧪 Phase 7: Kubernetes Readiness"
echo "-------------------------------"
check_item "Kubelet service exists" "systemctl cat kubelet"
check_item "Kubeadm command available" "command -v kubeadm"
check_item "Kubectl command available" "command -v kubectl"
check_item "Docker/containerd socket" "test -S /run/containerd/containerd.sock"

echo ""
echo "📊 VERIFICATION SUMMARY"
echo "====================="

PASS_RATE=$((PASSED_CHECKS * 100 / TOTAL_CHECKS))

echo "Total Checks: $TOTAL_CHECKS"
echo "Passed: $PASSED_CHECKS"
echo "Failed: $((TOTAL_CHECKS - PASSED_CHECKS))"
echo "Pass Rate: $PASS_RATE%"

echo ""
if [ $PASS_RATE -ge 95 ]; then
    echo -e "${GREEN}🎉 ULTRA TEMPLATE VERIFICATION: EXCELLENT ($PASS_RATE%)${NC}"
    echo -e "${GREEN}✅ Template is ready for 25-30 second deployments!${NC}"
    
    echo ""
    echo "🚀 Next Steps:"
    echo "1. Shutdown this VM gracefully"
    echo "2. Convert to template in Proxmox"
    if [ -f "/etc/centos-release" ] || [ -f "/etc/redhat-release" ]; then
        echo "3. Name it: t-centos9-ultra-k8s"
    else
        echo "3. Name it: t-debian12-ultra-k8s"  
    fi
    echo "4. Use in Jenkins pipeline for ULTRA-FAST deployment!"
    
elif [ $PASS_RATE -ge 80 ]; then
    echo -e "${YELLOW}⚠️  ULTRA TEMPLATE VERIFICATION: GOOD ($PASS_RATE%)${NC}"
    echo -e "${YELLOW}Some optimizations may be missing - review failed checks${NC}"
    
elif [ $PASS_RATE -ge 60 ]; then
    echo -e "${YELLOW}⚠️  ULTRA TEMPLATE VERIFICATION: FAIR ($PASS_RATE%)${NC}" 
    echo -e "${YELLOW}Multiple optimizations missing - re-run creation script${NC}"
    
else
    echo -e "${RED}❌ ULTRA TEMPLATE VERIFICATION: FAILED ($PASS_RATE%)${NC}"
    echo -e "${RED}Template is NOT ready - re-run ultra creation script${NC}"
fi

echo ""
echo "💡 Template Creation Scripts:"
echo "   Debian: ./scripts/create-ultra-optimized-k8s-template.sh"
echo "   CentOS: ./scripts/create-ultra-optimized-centos9-k8s-template.sh"

exit $([ $PASS_RATE -ge 95 ] && echo 0 || echo 1)