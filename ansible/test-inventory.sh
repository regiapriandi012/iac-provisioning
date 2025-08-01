#!/bin/bash
#
# Test script untuk melihat inventory yang di-generate
#

echo "=== Testing Dynamic Inventory Generator ==="
echo

# Test dengan CSV yang ada
CSV_FILE="../terraform/vms.csv"
echo "Reading from: $CSV_FILE"
echo "Current VMs:"
cat "$CSV_FILE"
echo

echo "=== Generated Inventory ==="
python3 ./generate_inventory.py "$CSV_FILE"
echo

echo "=== Testing Different Scenarios ==="

# Test scenario 1: Single master
echo -e "\n--- Scenario 1: Single Master ---"
cat > /tmp/single-master.csv << EOF
vmid,vm_name,template,node,ip,cores,memory,disk_size
0,kube-master,t-centos9-86,thinkcentre,192.168.1.10,2,4096,32G
0,kube-worker01,t-centos9-86,thinkcentre,192.168.1.11,2,4096,32G
0,kube-worker02,t-centos9-86,thinkcentre,192.168.1.12,2,4096,32G
EOF
python3 ./generate_inventory.py /tmp/single-master.csv

# Test scenario 2: Multi-master HA
echo -e "\n--- Scenario 2: Multi-Master HA ---"
cat > /tmp/multi-master.csv << EOF
vmid,vm_name,template,node,ip,cores,memory,disk_size
0,kube-master01,t-centos9-86,thinkcentre,192.168.1.10,2,4096,32G
0,kube-master02,t-centos9-86,thinkcentre,192.168.1.11,2,4096,32G
0,kube-master03,t-centos9-86,thinkcentre,192.168.1.12,2,4096,32G
0,kube-worker01,t-centos9-86,thinkcentre,192.168.1.20,2,4096,32G
0,kube-worker02,t-centos9-86,thinkcentre,192.168.1.21,2,4096,32G
EOF
python3 ./generate_inventory.py /tmp/multi-master.csv

# Test scenario 3: With dedicated load balancer
echo -e "\n--- Scenario 3: With Dedicated HAProxy LB ---"
cat > /tmp/with-lb.csv << EOF
vmid,vm_name,template,node,ip,cores,memory,disk_size
0,kube-lb,t-centos9-86,thinkcentre,192.168.1.100,1,2048,20G
0,kube-master01,t-centos9-86,thinkcentre,192.168.1.10,2,4096,32G
0,kube-master02,t-centos9-86,thinkcentre,192.168.1.11,2,4096,32G
0,kube-worker01,t-centos9-86,thinkcentre,192.168.1.20,2,4096,32G
EOF
python3 ./generate_inventory.py /tmp/with-lb.csv

echo -e "\n=== Cleanup ==="
rm -f /tmp/single-master.csv /tmp/multi-master.csv /tmp/with-lb.csv