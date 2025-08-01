output "vm_assignments" {
  description = "VM assignments with source information"
  value = {
    for vm_name, vm_data in local.vm_data : vm_name => {
      vmid        = vm_data.vmid
      vmid_source = vm_data.vmid_source
      ip_address  = vm_data.ip_address
      ip_source   = vm_data.ip_source
    }
  }
}

output "created_vms" {
  description = "Information about created VMs"
  value = {
    for k, v in proxmox_vm_qemu.vms : k => {
      vmid = v.vmid
      name = v.name
      node = v.target_node
      ip   = v.ipconfig0
      cores = v.cores
      memory = v.memory
    }
  }
}

output "assignment_summary" {
  description = "Summary of how IDs and IPs were assigned"
  value = {
    defined_vmids = length([for vm in local.vm_data : vm if vm.vmid_source == "defined"])
    random_vmids  = length([for vm in local.vm_data : vm if vm.vmid_source == "random"])
    defined_ips   = length([for vm in local.vm_data : vm if vm.ip_source == "defined"])
    random_ips    = length([for vm in local.vm_data : vm if vm.ip_source == "random"])
    total_vms     = length(local.vm_data)
  }
}