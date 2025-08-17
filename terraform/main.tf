terraform {
  required_providers {
    proxmox = {
        source = "Telmate/proxmox"
        version = "3.0.1-rc4"
    }
    random = {
      source = "hashicorp/random"
      version = "~> 3.1"
    }
    local = {
      source = "hashicorp/local"
      version = "~> 2.1"
    }
  }
}

provider "proxmox" {
    pm_api_url = var.pm_api_url
    pm_api_token_id = var.pm_api_token_id
    pm_api_token_secret = var.pm_api_token_secret
    
    # Optimize parallel API requests
    pm_parallel = 10
    pm_timeout = 600
}

# Generate random suffix yang sama untuk semua VM dalam satu provision
resource "random_string" "vm_suffix" {
  length  = 12
  special = false
  upper   = false
}

# Generate base VMID untuk sequential assignment
resource "random_integer" "vmid_base" {
  min = 10000
  max = 19000
}

# Generate base IP untuk sequential assignment
resource "random_integer" "ip_base" {
  min = 30
  max = 200
}

# Generate VM configurations directly from Terraform variables
locals {
  # Generate master nodes based on variable
  master_vms = {
    for i in range(var.master_node_count) : "kube-master${format("%02d", i + 1)}" => {
      vm_name_original = "kube-master${format("%02d", i + 1)}"
      vm_name_final    = "kube-master${format("%02d", i + 1)}-${random_string.vm_suffix.result}"
      template         = var.vm_template
      node            = var.proxmox_node
      cores           = var.vm_cores
      memory          = var.vm_memory
      disk_size       = var.vm_disk_size
      vmid            = random_integer.vmid_base.result + i
      ip_address      = "10.200.0.${random_integer.ip_base.result + i}"
      ip              = "ip=10.200.0.${random_integer.ip_base.result + i}/24,gw=${var.gateway}"
      vmid_source     = "sequential"
      ip_source       = "sequential"
      batch_index     = i % 3
      node_type       = "master"
    }
  }
  
  # Generate worker nodes based on variable
  worker_vms = {
    for i in range(var.worker_node_count) : "kube-worker${format("%02d", i + 1)}" => {
      vm_name_original = "kube-worker${format("%02d", i + 1)}"
      vm_name_final    = "kube-worker${format("%02d", i + 1)}-${random_string.vm_suffix.result}"
      template         = var.vm_template
      node            = var.proxmox_node
      cores           = var.vm_cores
      memory          = var.vm_memory
      disk_size       = var.vm_disk_size
      vmid            = random_integer.vmid_base.result + var.master_node_count + i
      ip_address      = "10.200.0.${random_integer.ip_base.result + var.master_node_count + i}"
      ip              = "ip=10.200.0.${random_integer.ip_base.result + var.master_node_count + i}/24,gw=${var.gateway}"
      vmid_source     = "sequential"
      ip_source       = "sequential"
      batch_index     = (var.master_node_count + i) % 3
      node_type       = "worker"
    }
  }
  
  # Combine master and worker VMs
  vm_data = merge(local.master_vms, local.worker_vms)
}

# Resource dengan for_each loop dan optimizations
resource "proxmox_vm_qemu" "vms" {
    for_each = local.vm_data
   
    vmid = each.value.vmid
    name = each.value.vm_name_final  # Menggunakan nama dengan suffix random
    target_node = each.value.node
    clone = each.value.template
    full_clone = true
    cores = each.value.cores
    sockets = 1
    vcpus = each.value.cores
    memory = each.value.memory
    cpu = "host"
    scsihw = "virtio-scsi-pci"
    
    # Optimized VM startup options
    additional_wait = 15  # Reduced from 30
    agent = 1
    automatic_reboot = true
    clone_wait = 15       # Reduced from 30
    
    # Parallel creation optimization
    lifecycle {
      create_before_destroy = false
    }
    
    # Setup the disk
    disks {
        # Disk utama (virtio)
        virtio {
            virtio0 {
                disk {
                    size = each.value.disk_size
                    storage = var.storage
                    format = "raw"
                    replicate = false
                    cache = "writeback"  # Better performance
                    discard = true       # Enable TRIM
                }
            }
        }
        ide {
            ide1 {
                cloudinit {
                    storage = var.storage
                }
            }
        }
    }
    
    # Setup the network interface
    network {
        model = "virtio"
        bridge = "vmbr0"
        firewall = false
    }
    
    # Staggered startup to avoid boot storms
    startup = "order=${each.value.batch_index + 1},up=15"
    onboot = true
    
    # Cloud-init configuration
    ipconfig0  = each.value.ip
    ciuser     = "root"
    cipassword = "$5$/HZS4GxE$N13RjjmJU/iXn2g9hjK.7z52TdMa981KZiaGj6l0vm8"
   
    sshkeys = join("\n", var.ssh_keys)
   
    nameserver   = "8.8.8.8"
    searchdomain = "localhost.localdomain"
   
    serial {
      id   = 0
      type = "socket"
    }
    
    # Tags untuk identifikasi
    tags = "terraform,${each.value.vm_name_original}"
    
    # Provisioner untuk early network readiness check
    provisioner "local-exec" {
      command = "sleep 5"  # Small delay before readiness check
    }
}


