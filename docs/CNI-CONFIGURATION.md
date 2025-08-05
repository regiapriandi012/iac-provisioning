# Dynamic CNI Configuration

Sistem ini mendukung konfigurasi CNI (Container Network Interface) yang dinamis, memungkinkan Anda memilih jenis CNI yang ingin digunakan saat deployment.

## CNI yang Didukung

1. **Cilium** (default)
   - Version: 1.14.5
   - Features: Advanced networking, security policies, observability
   - Best for: Production clusters dengan kebutuhan security tinggi

2. **Calico**
   - Version: 3.27.0 
   - Features: Network policies, BGP routing, scalability
   - Best for: Large-scale deployments dengan kebutuhan network policy

3. **Flannel**
   - Version: latest
   - Features: Simple overlay network
   - Best for: Simple clusters, development environment

4. **Weave Net**
   - Version: 2.8.1
   - Features: Simple setup, built-in DNS
   - Best for: Development dan testing environment

## Cara Penggunaan

### 1. Melalui Jenkins Pipeline

Saat menjalankan Jenkins pipeline:

1. Pilih **CNI Type** dari dropdown:
   - cilium (default)
   - calico
   - flannel 
   - weave

2. Atur **CNI Version** sesuai kebutuhan:
   - Cilium: 1.14.5, 1.15.0, etc.
   - Calico: 3.27.0, 3.26.0, etc.
   - Flannel: latest (recommended)
   - Weave: 2.8.1, 2.8.0, etc.

### 2. Melalui Environment Configuration

Edit file `config/environment.conf`:

```bash
# CNI Configuration
DEFAULT_CNI_TYPE=calico
DEFAULT_CNI_VERSION=3.27.0
```

### 3. Melalui Manual Deployment

Set environment variables:

```bash
export TF_VAR_cni_type=flannel
export TF_VAR_cni_version=latest
```

## Validasi

Setelah deployment, verifikasi CNI yang terpasang:

```bash
# Check CNI pods
kubectl get pods -n kube-system | grep -E "(cilium|calico|flannel|weave)"

# Check nodes status
kubectl get nodes -o wide

# For Cilium specifically
cilium status
```

## Network CIDR Configuration

Default network configuration:
- Pod Network CIDR: `10.244.0.0/16`
- Service CIDR: `10.96.0.0/12`

Untuk Calico, pastikan Pod Network CIDR sesuai dengan konfigurasi di playbook Ansible.

## Troubleshooting

### 1. CNI Pods tidak Running

```bash
kubectl describe pods -n kube-system | grep -A 10 -B 5 Error
```

### 2. Nodes dalam status NotReady

```bash
kubectl describe node <node-name>
```

### 3. Network connectivity issues

```bash
# Test pod-to-pod communication
kubectl run test-pod --image=busybox --rm -it -- /bin/sh
```

## Notes

- Perubahan CNI type memerlukan rebuild cluster
- Setiap CNI memiliki karakteristik performa yang berbeda
- Untuk production, disarankan menggunakan Cilium atau Calico