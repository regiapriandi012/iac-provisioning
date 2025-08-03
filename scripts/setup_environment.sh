#!/bin/bash
# Setup Environment Script
# Configures Python virtual environment and caching for the build pipeline

set -e

# Create cache directories if caching is enabled
if [ "$USE_CACHE" = "true" ]; then
    mkdir -p ${CACHE_DIR}/terraform ${CACHE_DIR}/ansible ${CACHE_DIR}/python
fi

# Setup Python virtual environment
echo "Setting up Python virtual environment..."

# Check if venv exists in cache
if [ "$USE_CACHE" = "true" ] && [ -d "${CACHE_DIR}/python/venv" ]; then
    echo "Using cached Python venv"
    cp -r ${CACHE_DIR}/python/venv ${WORKSPACE}/venv || true
fi

# Create venv if it doesn't exist
if [ ! -d "${WORKSPACE}/venv" ]; then
    echo "Creating new Python venv..."
    python3 -m venv ${WORKSPACE}/venv
fi

# Activate venv and install required packages
. ${WORKSPACE}/venv/bin/activate

# Check if packages are already installed
NEED_INSTALL=false
if ! python3 -c "import asyncssh" 2>/dev/null; then
    NEED_INSTALL=true
fi
if ! python3 -c "import mitogen" 2>/dev/null; then
    NEED_INSTALL=true
fi

if [ "$NEED_INSTALL" = "true" ]; then
    echo "Installing required Python packages..."
    pip install --upgrade pip
    pip install asyncssh paramiko mitogen
else
    echo "Python packages already installed"
fi

# Setup Mitogen for Ansible (ULTRA-FAST performance)
cd ${ANSIBLE_DIR}
if [ -f "${WORKSPACE}/scripts/setup_mitogen.py" ]; then
    echo "Setting up Mitogen for ULTRA-FAST Ansible performance..."
    python3 ${WORKSPACE}/scripts/setup_mitogen.py || true
    python3 ${WORKSPACE}/scripts/mitogen_ansible_cfg.py || true
fi
cd ${WORKSPACE}

# Cache the venv for future use
if [ "$USE_CACHE" = "true" ]; then
    echo "Caching Python venv..."
    cp -r ${WORKSPACE}/venv ${CACHE_DIR}/python/ || true
fi

# Check Terraform cache
if [ "$USE_CACHE" = "true" ] && [ -d "${TERRAFORM_DIR}" ]; then
    if [ -d "${CACHE_DIR}/terraform/.terraform" ]; then
        echo "Using cached Terraform providers"
        cp -r ${CACHE_DIR}/terraform/.terraform ${TERRAFORM_DIR}/ || true
    fi
fi