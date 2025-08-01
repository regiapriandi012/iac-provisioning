#!/bin/bash
#
# Test Sequential IP and VMID Assignment Logic
#

echo "=== Testing Sequential Assignment Logic ==="

# Test scenario 1: All auto-assign (vmid=0, ip=0)
echo "Scenario 1: All auto-assign"
cat > /tmp/test-auto.csv << 'EOF'
vmid,vm_name,template,node,ip,cores,memory,disk_size
0,kube-master,t-centos9-86,thinkcentre,0,2,4096,32G
0,kube-worker01,t-centos9-86,thinkcentre,0,2,4096,32G
0,kube-worker02,t-centos9-86,thinkcentre,0,2,4096,32G
EOF

echo "Expected: Sequential IPs like 192.168.1.10, 192.168.1.11, 192.168.1.12"
python3 generate_inventory.py /tmp/test-auto.csv | jq -r '._meta.hostvars | to_entries[] | "\(.key): \(.value.ansible_host)"' 2>/dev/null || python3 generate_inventory.py /tmp/test-auto.csv | grep -E "(kube-.*|ansible_host)"

echo

# Test scenario 2: Mix of manual and auto-assign
echo "Scenario 2: Mixed assignment"
cat > /tmp/test-mixed.csv << 'EOF'
vmid,vm_name,template,node,ip,cores,memory,disk_size
100,kube-master,t-centos9-86,thinkcentre,10.200.0.50,2,4096,32G
0,kube-worker01,t-centos9-86,thinkcentre,0,2,4096,32G
0,kube-worker02,t-centos9-86,thinkcentre,0,2,4096,32G
EOF

echo "Expected: Master uses 10.200.0.50, workers get sequential fallback IPs"
python3 generate_inventory.py /tmp/test-mixed.csv | jq -r '._meta.hostvars | to_entries[] | "\(.key): \(.value.ansible_host)"' 2>/dev/null || python3 generate_inventory.py /tmp/test-mixed.csv | grep -E "(kube-.*|ansible_host)"

echo

# Test scenario 3: IP with subnet mask
echo "Scenario 3: IP with subnet mask (simulating Terraform output)"
cat > /tmp/test-subnet.csv << 'EOF'
vmid,vm_name,template,node,ip,cores,memory,disk_size
10001,kube-master,t-centos9-86,thinkcentre,10.200.0.56/24,2,4096,32G
10002,kube-worker01,t-centos9-86,thinkcentre,10.200.0.57/24,2,4096,32G
10003,kube-worker02,t-centos9-86,thinkcentre,10.200.0.58/24,2,4096,32G
EOF

echo "Expected: IPs without /24 subnet mask"
python3 generate_inventory.py /tmp/test-subnet.csv | jq -r '._meta.hostvars | to_entries[] | "\(.key): \(.value.ansible_host)"' 2>/dev/null || python3 generate_inventory.py /tmp/test-subnet.csv | grep -E "(kube-.*|ansible_host)"

# Cleanup
rm -f /tmp/test-*.csv

echo
echo "=== Sequential Assignment Test Complete ==="