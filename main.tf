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
  }
}

provider "proxmox" {
    pm_api_url = var.pm_api_url
    pm_api_token_id = var.pm_api_token_id
    pm_api_token_secret = var.pm_api_token_secret
}

# Generate random VMID untuk VMs yang vmid = 0
resource "random_integer" "vmid" {
  for_each = { 
    for vm in csvdecode(file(var.vm_csv_file)) : vm.vm_name => vm 
    if tonumber(vm.vmid) == 0
  }
  
  min = 10000
  max = 20000
  
  keepers = {
    vm_name = each.value.vm_name
  }
}

# Generate random IP untuk VMs yang ip = 0
resource "random_integer" "ip_octet" {
  for_each = { 
    for vm in csvdecode(file(var.vm_csv_file)) : vm.vm_name => vm 
    if vm.ip == "0"
  }
  
  min = 10
  max = 240
  
  keepers = {
    vm_name = each.value.vm_name
  }
}

# Local untuk memproses data VM dengan hybrid approach
locals {
  vm_data_raw = csvdecode(file(var.vm_csv_file))
  
  vm_data = {
    for vm in local.vm_data_raw : vm.vm_name => {
      # Use defined VMID or random (if vmid = 0)
      vmid = tonumber(vm.vmid) != 0 ? tonumber(vm.vmid) : random_integer.vmid[vm.vm_name].result
      
      vm_name   = vm.vm_name
      template  = vm.template
      node      = vm.node
      
      # Use defined IP or random (if ip = "0")
      ip_address = vm.ip != "0" ? vm.ip : "10.200.0.${random_integer.ip_octet[vm.vm_name].result}"
      ip         = vm.ip != "0" ? "ip=${vm.ip}/24,gw=${var.gateway}" : "ip=10.200.0.${random_integer.ip_octet[vm.vm_name].result}/24,gw=${var.gateway}"
      
      cores     = tonumber(vm.cores)
      memory    = tonumber(vm.memory)
      disk_size = vm.disk_size
      
      # Flag untuk tracking
      vmid_source = tonumber(vm.vmid) != 0 ? "defined" : "random"
      ip_source   = vm.ip != "0" ? "defined" : "random"
    }
  }
}

# Resource dengan for_each loop
resource "proxmox_vm_qemu" "vms" {
    for_each = local.vm_data
    
    vmid = each.value.vmid
    name = each.value.vm_name

    target_node = each.value.node

    clone = each.value.template
    full_clone = true

    cores = each.value.cores
    sockets = 1
    vcpus = each.value.cores
    memory = each.value.memory
    cpu = "host"
    scsihw = "virtio-scsi-pci"

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
    }

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
    tags = "terraform,${each.value.vm_name}"
}