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
  
  # Group VMs by template for efficient cloning
  vms_by_template = {
    for template in distinct([for vm in local.vm_data_raw : vm.template]) :
    template => [for vm in local.vm_data_raw : vm if vm.template == template]
  }
 
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
      ip_address = vm.ip != "0" ? vm.ip : "10.200.0.${random_integer.ip_base.result + index(local.vms_need_auto_ip, vm)}"
      ip         = vm.ip != "0" ? "ip=${vm.ip}/24,gw=${var.gateway}" : "ip=10.200.0.${random_integer.ip_base.result + index(local.vms_need_auto_ip, vm)}/24,gw=${var.gateway}"
     
      cores     = tonumber(vm.cores)
      memory    = tonumber(vm.memory)
      disk_size = vm.disk_size
     
      # Flag untuk tracking
      vmid_source = tonumber(vm.vmid) != 0 ? "defined" : "sequential"
      ip_source   = vm.ip != "0" ? "defined" : "sequential"
      
      # Batch index untuk staggered creation
      batch_index = index(local.vm_data_raw, vm) % 3
    }
  }
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

# Update CSV dengan sequential assignments
resource "local_file" "updated_csv" {
  depends_on = [proxmox_vm_qemu.vms]
  
  filename = var.vm_csv_file
  content  = join("\n", concat(
    ["vmid,vm_name,template,node,ip,cores,memory,disk_size"],
    [for name, vm in local.vm_data : 
      "${vm.vmid},${vm.vm_name_original},${vm.template},${vm.node},${vm.ip_address},${vm.cores},${vm.memory},${vm.disk_size}"
    ]
  ))
}

# Output untuk assignment summary
output "assignment_summary" {
    depends_on = [local_file.updated_csv]
    value = <<-EOF
    
    VM ASSIGNMENT SUMMARY
    ===================
    Total VMs Created: ${length(local.vm_data)}
    Random Suffix: ${random_string.vm_suffix.result}
    
    VMID Assignment:
    - Base VMID: ${random_integer.vmid_base.result}
    - Sequential VMs: ${length(local.vms_need_auto_vmid)}
    - Pre-defined VMs: ${length(local.vm_data_raw) - length(local.vms_need_auto_vmid)}
    
    IP Assignment:
    - Base IP: 10.200.0.${random_integer.ip_base.result}
    - Sequential IPs: ${length(local.vms_need_auto_ip)}
    - Pre-defined IPs: ${length(local.vm_data_raw) - length(local.vms_need_auto_ip)}
    
    Templates Used:
    %{ for template, vms in local.vms_by_template ~}
    - ${template}: ${length(vms)} VMs
    %{ endfor ~}
    
    Note: CSV file has been updated with all assigned values.
    EOF
}

# Output VM assignments dalam format yang mudah dibaca
output "vm_assignments" {
    depends_on = [local_file.updated_csv]
    value = {
        for name, vm in local.vm_data : name => {
            final_name = vm.vm_name_final
            vmid       = vm.vmid
            ip_address = vm.ip_address
            vmid_type  = vm.vmid_source
            ip_type    = vm.ip_source
        }
    }
}

# Output untuk Ansible inventory dengan optimized format
output "ansible_inventory_json" {
  depends_on = [proxmox_vm_qemu.vms]
  value = jsonencode({
    all = {
      hosts = {
        for name, vm in local.vm_data : 
        vm.vm_name_original => {
          ansible_host = vm.ip_address
          ansible_user = "root"
          ansible_ssh_pass = "Passw0rd!"
          ansible_ssh_common_args = "-o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -o ConnectTimeout=10"
          template = vm.template
          cores = vm.cores
          memory = vm.memory
          disk_size = vm.disk_size
        }
      }
      children = {
        k8s_masters = {
          hosts = {
            for name, vm in local.vm_data :
            vm.vm_name_original => null
            if can(regex("master", lower(vm.vm_name_original)))
          }
        }
        k8s_workers = {
          hosts = {
            for name, vm in local.vm_data :
            vm.vm_name_original => null
            if can(regex("worker", lower(vm.vm_name_original)))
          }
        }
      }
    }
  })
}