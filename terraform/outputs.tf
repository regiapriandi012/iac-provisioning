# Local variables for inventory generation
locals {
  masters = [for k, v in local.vm_data : v if can(regex("master", lower(v.vm_name_original)))]
  master_count = length(local.masters)
  first_master_ip = length(local.masters) > 0 ? replace(local.masters[0].ip_address, "/.*", "") : ""
  # Calculate HAProxy VIP as IP base - 1
  haproxy_vip = "10.200.0.${random_integer.ip_base.result - 1}"
}

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

# Generate simple inventory untuk Ansible
output "ansible_inventory_ini" {
  description = "Ansible inventory in INI format"
  value = <<-EOT
[all:vars]
ansible_user=root
ansible_ssh_common_args='-o StrictHostKeyChecking=no'

[kube_masters]
%{for k, v in local.vm_data~}
%{if can(regex("master", lower(v.vm_name_original)))~}
${v.vm_name_final} ansible_host=${replace(v.ip_address, "/.*", "")} vmid=${v.vmid}
%{endif~}
%{endfor~}

[kube_workers]
%{for k, v in local.vm_data~}
%{if can(regex("worker", lower(v.vm_name_original)))~}
${v.vm_name_final} ansible_host=${replace(v.ip_address, "/.*", "")} vmid=${v.vmid}
%{endif~}
%{endfor~}

[kube_all:children]
kube_masters
kube_workers
EOT
}

# Generate JSON inventory untuk flexibility
output "ansible_inventory_json" {
  description = "Ansible inventory in JSON format"
  value = jsonencode({
    all = {
      vars = merge({
        ansible_user = "root"
        ansible_ssh_common_args = "-o StrictHostKeyChecking=no"
        master_count = local.master_count
        is_ha_cluster = local.master_count > 1
        pod_network_cidr = "10.244.0.0/16"
        service_cidr = "10.96.0.0/12"
        kubernetes_version = var.kubernetes_version
        container_runtime = "containerd"
        cni_type = var.cni_type
        cni_version = var.cni_version
      }, local.master_count > 1 ? {
        # For HA cluster without external load balancer, use first master IP
        # In production, this should point to a proper load balancer
        control_plane_endpoint = "${local.first_master_ip}:6443"
        haproxy_vip = local.haproxy_vip
        haproxy_port = "6443"
        etcd_cluster = true
      } : {
        control_plane_endpoint = "${local.first_master_ip}:6443"
      })
    }
    k8s_masters = {
      hosts = {
        for k, v in local.vm_data : v.vm_name_final => {
          ansible_host = replace(v.ip_address, "/.*", "")
          vmid = v.vmid
          node = v.node
          original_name = v.vm_name_original
          template = v.template
        } if can(regex("master", lower(v.vm_name_original)))
      }
    }
    k8s_workers = {
      hosts = {
        for k, v in local.vm_data : v.vm_name_final => {
          ansible_host = replace(v.ip_address, "/.*", "")
          vmid = v.vmid
          node = v.node
          original_name = v.vm_name_original
          template = v.template
        } if can(regex("worker", lower(v.vm_name_original)))
      }
    }
    k8s_cluster = {
      children = {
        k8s_masters = {}
        k8s_workers = {}
      }
    }
  })
}

# Export VM data sebagai CSV untuk dynamic inventory generator
resource "local_file" "vms_csv" {
  content = <<-EOT
vmid,vm_name,template,node,ip,cores,memory,disk_size
%{for k, v in local.vm_data~}
${v.vmid},${v.vm_name_original},${v.template},${v.node},${v.ip_address},${v.cores},${v.memory},${v.disk_size}
%{endfor~}
EOT
  filename = "${path.module}/vms.csv"

  depends_on = [proxmox_vm_qemu.vms]
}