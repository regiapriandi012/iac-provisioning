output "vm_assignments" {
  description = "VM assignments with source information"
  value = {
    for vm_name, vm_data in local.vm_data : vm_name => {
      original_name = vm_data.vm_name_original
      final_name    = vm_data.vm_name_final
      random_suffix = random_string.vm_suffix.result
      vmid          = vm_data.vmid
      vmid_source   = vm_data.vmid_source
      ip_address    = vm_data.ip_address
      ip_source     = vm_data.ip_source
    }
  }
}

output "created_vms" {
  description = "Information about created VMs"
  value = {
    for k, v in proxmox_vm_qemu.vms : k => {
      original_name = local.vm_data[k].vm_name_original
      final_name    = v.name
      vmid          = v.vmid
      node          = v.target_node
      ip            = v.ipconfig0
      cores         = v.cores
      memory        = v.memory
    }
  }
}

output "assignment_summary" {
  description = "Summary of how IDs and IPs were assigned"
  value = {
    defined_vmids    = length([for vm in local.vm_data : vm if vm.vmid_source == "defined"])
    sequential_vmids = length([for vm in local.vm_data : vm if vm.vmid_source == "sequential"])
    defined_ips      = length([for vm in local.vm_data : vm if vm.ip_source == "defined"])
    sequential_ips   = length([for vm in local.vm_data : vm if vm.ip_source == "sequential"])
    total_vms        = length(local.vm_data)
    vmid_base        = random_integer.vmid_base.result
    ip_base          = random_integer.ip_base.result
    shared_suffix    = random_string.vm_suffix.result
  }
}

output "vm_name_mapping" {
  description = "Mapping of original names to final names with random suffixes"
  value = {
    for vm_name, vm_data in local.vm_data : vm_data.vm_name_original => {
      final_name    = vm_data.vm_name_final
      random_suffix = random_string.vm_suffix.result
    }
  }
}