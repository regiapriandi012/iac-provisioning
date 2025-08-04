#!/bin/bash
# Environment Validation Script
# Validates that all environment-specific configurations are properly set

set -e

echo "🔍 Validating Environment Configuration..."

# Check if placeholders are still present in CSV
if [ -f "terraform/vms.csv" ]; then
    if grep -q "TEMPLATE_PLACEHOLDER\|NODE_PLACEHOLDER" terraform/vms.csv; then
        echo "❌ ERROR: Placeholders found in vms.csv"
        echo "   Please ensure default_vm_template and default_proxmox_node parameters are set"
        echo "   or replace placeholders manually in vm_csv_content parameter"
        exit 1
    else
        echo "✅ CSV configuration validated - no placeholders found"
    fi
fi

# Validate that we're not using hardcoded paths
HARDCODED_PATHS=()

# Check for hardcoded workspace paths in scripts
if grep -r "/root/coder/iac-provision" scripts/ 2>/dev/null; then
    HARDCODED_PATHS+=("Hardcoded workspace paths found in scripts/")
fi

# Check for hardcoded server-specific values
if grep -r "thinkcentre" terraform/ 2>/dev/null | grep -v "default\|example\|placeholder"; then
    HARDCODED_PATHS+=("Hardcoded 'thinkcentre' found in terraform files")
fi

if grep -r "t-debian12-86" terraform/ 2>/dev/null | grep -v "default\|example\|placeholder"; then
    HARDCODED_PATHS+=("Hardcoded 't-debian12-86' found in terraform files")  
fi

# Check for hardcoded Git URLs (excluding documentation)
if grep -r "gitlab.labngoprek.my.id" . 2>/dev/null | grep -v "README\|DOCUMENTATION\|\.md\|\.git\|default\|example"; then
    HARDCODED_PATHS+=("Hardcoded Git URL found outside documentation")
fi

# Report validation results
if [ ${#HARDCODED_PATHS[@]} -eq 0 ]; then
    echo "✅ Environment validation passed - no hardcoded values detected"
else
    echo "❌ Environment validation failed:"
    for path in "${HARDCODED_PATHS[@]}"; do
        echo "   - $path"
    done
    echo ""
    echo "💡 This means the project may not work correctly in different environments."
    echo "   Please review and make these values configurable."
    exit 1
fi

# Validate Jenkins credentials format (if running in Jenkins)
if [ -n "$JENKINS_URL" ]; then
    echo "🔧 Validating Jenkins environment..."
    
    # Check if required environment variables are set
    REQUIRED_VARS=("WORKSPACE" "BUILD_NUMBER" "JOB_NAME")
    for var in "${REQUIRED_VARS[@]}"; do
        if [ -z "${!var}" ]; then
            echo "❌ ERROR: Required Jenkins variable $var is not set"
            exit 1
        fi
    done
    
    echo "✅ Jenkins environment validated"
fi

# Validate workspace is dynamic
if [ -n "$WORKSPACE" ]; then
    CURRENT_WORKSPACE="$WORKSPACE"
else
    CURRENT_WORKSPACE="$(pwd)"
fi

echo "✅ Using workspace: $CURRENT_WORKSPACE"

# Check if all scripts use relative paths
echo "🔍 Validating script path usage..."
SCRIPT_ISSUES=()

# Check if scripts use ${WORKSPACE} properly
if grep -r "\${WORKSPACE}" scripts/ | grep -v "venv/bin/python\|/scripts/"; then
    SCRIPT_ISSUES+=("Some scripts may have incorrect WORKSPACE usage")
fi

if [ ${#SCRIPT_ISSUES[@]} -eq 0 ]; then
    echo "✅ Script path validation passed"
else
    echo "⚠️  Script path warnings:"
    for issue in "${SCRIPT_ISSUES[@]}"; do
        echo "   - $issue"
    done
fi

echo ""
echo "🎉 Environment validation completed successfully!"
echo "   Project is ready for deployment in any environment."