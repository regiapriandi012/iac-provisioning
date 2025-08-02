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

# Local untuk memproses data VM dengan hybrid approach
locals {
  vm_data_raw = csvdecode(file(var.vm_csv_file))
  
  # Create list of VMs that need auto IP, sorted by name for consistency
  vms_need_auto_ip = [
    for vm in local.vm_data_raw : vm if vm.ip == "0"
  ]
  
  # Create list of VMs that need auto VMID
  vms_need_auto_vmid = [
    for vm in local.vm_data_raw : vm if tonumber(vm.vmid) == 0
  ]
 
  vm_data = {
    for i, vm in local.vm_data_raw : vm.vm_name => {
      # Use defined VMID or sequential VMID (if vmid = 0)
      vmid = tonumber(vm.vmid) != 0 ? tonumber(vm.vmid) : random_integer.vmid_base.result + index(local.vms_need_auto_vmid, vm)
     
      # Generate VM name with same random suffix for all VMs
      vm_name_original = vm.vm_name
      vm_name_final    = "${vm.vm_name}-${random_string.vm_suffix.result}"
      
      template  = vm.template
      node      = vm.node
     
      # Use defined IP or sequential IP (if ip = "0")
      # Reserve first IP (base-1) for HAProxy LB when multi-master
      ip_offset = index(local.vms_need_auto_ip, vm)
      ip_address = vm.ip != "0" ? vm.ip : "10.200.0.${random_integer.ip_base.result + ip_offset}"
      ip         = vm.ip != "0" ? "ip=${vm.ip}/24,gw=${var.gateway}" : "ip=10.200.0.${random_integer.ip_base.result + ip_offset}/24,gw=${var.gateway}"
     
      cores     = tonumber(vm.cores)
      memory    = tonumber(vm.memory)
      disk_size = vm.disk_size
     
      # Flag untuk tracking
      vmid_source = tonumber(vm.vmid) != 0 ? "defined" : "sequential"
      ip_source   = vm.ip != "0" ? "defined" : "sequential"
    }
  }
}

# Resource dengan for_each loop
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
    
    # VM startup options
    additional_wait = 30
    agent = 1
    automatic_reboot = true
    clone_wait = 30
    
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
    
    # Wait untuk network ready
    startup = "order=1,up=30"
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
}