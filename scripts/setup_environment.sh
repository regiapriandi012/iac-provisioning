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

# Always recreate venv for now to ensure latest packages
echo "Creating fresh Python venv..."
rm -rf ${WORKSPACE}/venv
python3 -m venv ${WORKSPACE}/venv

# Activate venv and install required packages
. ${WORKSPACE}/venv/bin/activate

# Install required packages (fresh venv so always install)
echo "Installing required Python packages..."
pip install --upgrade pip
pip install asyncssh paramiko mitogen PyYAML

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