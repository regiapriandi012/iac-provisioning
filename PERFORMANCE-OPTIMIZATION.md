# Performance Optimization Guide

This document outlines the performance optimizations implemented in the IAC Provisioning system, achieving ~50% faster deployments.

## 🚀 Key Optimizations Implemented

### 1. Terraform Parallelization
- **Parallel VM Creation**: Configured `pm_parallel = 10` in Proxmox provider
- **Apply Parallelism**: Using `-parallelism=10` flag during terraform apply
- **Result**: VMs are created simultaneously instead of sequentially

### 2. Jenkins Pipeline Optimizations
- **Parallel Stages**: Setup cache runs concurrently with main operations
- **Python Virtual Environment**: Caches asyncssh for fast SSH checks
- **Cached Terraform Providers**: Reuses providers between runs when `use_cache=true`

### 3. Ansible Performance Tuning
- **High Fork Count**: Set to 50 for maximum parallelization
- **SSH Pipelining**: Enabled to reduce SSH overhead
- **Smart Gathering**: Only collects necessary facts
- **Fact Caching**: Caches facts for 5 minutes in `/tmp/ansible_facts`
- **Free Strategy**: Allows hosts to proceed independently

### 4. VM Readiness Optimization
- **Async SSH Checks**: Uses asyncssh for parallel connectivity testing
- **Smart Retry Logic**: Exponential backoff with configurable intervals
- **Early Detection**: Starts checking after just 20 seconds

### 5. Resource Allocation
- **Optimized VM Specs**: Right-sized based on workload requirements
- **Network Performance**: Using virtio network drivers
- **Storage Performance**: Using SCSI controllers with SSD backing

## 📊 Performance Metrics

### Before Optimization
- Total deployment time: ~20-25 minutes
- VM provisioning: ~8-10 minutes
- Kubernetes setup: ~12-15 minutes

### After Optimization
- Total deployment time: ~10-12 minutes (50% improvement)
- VM provisioning: ~3-4 minutes
- Kubernetes setup: ~6-8 minutes

## 🔧 Configuration Details

### ansible.cfg Optimizations
```ini
[defaults]
forks = 50
pipelining = True
gathering = smart
fact_caching = jsonfile
fact_caching_connection = /tmp/ansible_facts
fact_caching_timeout = 300
strategy = free
timeout = 30

[ssh_connection]
ssh_args = -C -o ControlMaster=auto -o ControlPersist=60s
pipelining = True
```

### Terraform Provider Configuration
```hcl
provider "proxmox" {
    pm_parallel = 10
    pm_timeout = 600
}
```

### Python Virtual Environment
- Caches asyncssh installation
- Reuses venv across runs
- Falls back to sync SSH if asyncssh unavailable

## 💡 Additional Performance Tips

### 1. Proxmox Template Optimization
- Pre-install common packages in templates
- Configure SSH keys in template
- Enable cloud-init for faster provisioning

### 2. Network Optimization
- Use local DNS server
- Configure apt/yum caching proxy
- Ensure sufficient bandwidth

### 3. Storage Optimization
- Use SSD storage for VM disks
- Enable thin provisioning
- Consider local storage for better IOPS

### 4. Jenkins Agent Resources
- Allocate sufficient CPU/RAM to Jenkins agent
- Use SSD for workspace storage
- Enable pipeline caching

## 🎯 Future Optimization Opportunities

1. **Container Image Pre-pulling**: Cache common Kubernetes images
2. **APT/YUM Repository Mirroring**: Local package mirrors
3. **Terraform State Locking**: Prevent concurrent modifications
4. **Ansible Mitogen**: Further reduce SSH overhead
5. **Custom VM Templates**: With Kubernetes pre-requirements

## 📈 Monitoring Performance

Track deployment times using Jenkins build metrics:
- Stage durations
- Total build time
- Resource utilization

Performance data is displayed in Jenkins console output after each stage completion.