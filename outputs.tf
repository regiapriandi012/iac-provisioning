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

# Output untuk Ansible Inventory
output "ansible_inventory" {
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

[nginx_servers:children]
kube_all
EOT
}

# Output untuk Ansible Playbook
output "ansible_playbook" {
  description = "Ansible playbook for installing nginx"
  value = <<-EOT
---
- name: Install and configure nginx on all VMs
  hosts: nginx_servers
  become: yes
  gather_facts: yes
  
  vars:
    nginx_port: 80
    
  tasks:
    - name: Update package cache (CentOS/RHEL)
      yum:
        update_cache: yes
      when: ansible_os_family == "RedHat"
    
    - name: Update package cache (Debian/Ubuntu)
      apt:
        update_cache: yes
      when: ansible_os_family == "Debian"
    
    - name: Install nginx (CentOS/RHEL)
      yum:
        name: nginx
        state: present
      when: ansible_os_family == "RedHat"
    
    - name: Install nginx (Debian/Ubuntu)
      apt:
        name: nginx
        state: present
      when: ansible_os_family == "Debian"
    
    - name: Create custom index.html
      template:
        dest: /var/www/html/index.html
        content: |
          <!DOCTYPE html>
          <html>
          <head>
              <title>{{ ansible_hostname }}</title>
              <style>
                  body { font-family: Arial, sans-serif; margin: 40px; }
                  .header { background: #2c3e50; color: white; padding: 20px; border-radius: 5px; }
                  .info { background: #ecf0f1; padding: 15px; margin: 20px 0; border-radius: 5px; }
                  .status { color: #27ae60; font-weight: bold; }
              </style>
          </head>
          <body>
              <div class="header">
                  <h1>🚀 {{ ansible_hostname }}</h1>
                  <p>Nginx Server is Running!</p>
              </div>
              <div class="info">
                  <h3>Server Information:</h3>
                  <p><strong>Hostname:</strong> {{ ansible_hostname }}</p>
                  <p><strong>IP Address:</strong> {{ ansible_default_ipv4.address }}</p>
                  <p><strong>OS:</strong> {{ ansible_distribution }} {{ ansible_distribution_version }}</p>
                  <p><strong>Architecture:</strong> {{ ansible_architecture }}</p>
                  <p><strong>Kernel:</strong> {{ ansible_kernel }}</p>
                  <p><strong>VMID:</strong> {{ vmid }}</p>
              </div>
              <div class="info">
                  <p class="status">✅ Nginx installed and configured via Ansible!</p>
                  <p><small>Deployed on: $(date)</small></p>
              </div>
          </body>
          </html>
        mode: '0644'
      notify: restart nginx
    
    - name: Start and enable nginx
      systemd:
        name: nginx
        state: started
        enabled: yes
    
    - name: Open firewall for nginx (CentOS/RHEL)
      firewalld:
        service: http
        permanent: yes
        state: enabled
        immediate: yes
      when: ansible_os_family == "RedHat"
      ignore_errors: yes
    
    - name: Check nginx status
      uri:
        url: "http://{{ ansible_default_ipv4.address }}"
        method: GET
        status_code: 200
      register: nginx_check
      ignore_errors: yes
    
    - name: Display nginx status
      debug:
        msg: "✅ Nginx is running on http://{{ ansible_default_ipv4.address }}"
      when: nginx_check.status == 200
  
  handlers:
    - name: restart nginx
      systemd:
        name: nginx
        state: restarted
EOT
}