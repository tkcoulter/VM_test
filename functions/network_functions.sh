#!/bin/bash

# Functions for network and SSH operations

wait_for_vm_ip() {
    local vm_name="$1"
    local vm_ip=""
    local max_attempts=30
    local attempt=1
    
    echo "Waiting for VM to get IP address..." >&2
    
    while [ $attempt -le $max_attempts ]; do
        # Try domifaddr first
        vm_ip=$(virsh domifaddr "$vm_name" | grep -oE "\b([0-9]{1,3}\.){3}[0-9]{1,3}\b" | head -n 1)
        
        # If domifaddr didn't work, try domiflist + arp
        if [ -z "$vm_ip" ]; then
            local mac=$(virsh domiflist "$vm_name" | grep -o -E "([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}" | head -n 1)
            if [ ! -z "$mac" ]; then
                vm_ip=$(ip neigh show | grep -i "$mac" | cut -d' ' -f1)
            fi
        fi
        
        if [ ! -z "$vm_ip" ]; then
            echo "Found IP address: $vm_ip" >&2
            echo "$vm_ip"
            return 0
        fi
        
        echo "Attempt $attempt/$max_attempts - No IP address found yet..." >&2
        sleep 5
        ((attempt++))
    done
    
    echo "Failed to get IP address after $max_attempts attempts" >&2
    return 1
}

check_ssh_config() {
    local vm_ip="$1"
    echo "=== SSH Configuration Check ===" >&2
    
    # First check if port 22 is open
    if ! nc -z -w 5 "$vm_ip" 22; then
        echo "SSH port (22) is not open on $vm_ip" >&2
        return 1
    fi
    
    # Try to connect with verbose output to see what's happening
    echo "Testing SSH connection with verbose output..." >&2
    if ! sshpass -p "$VM_PASSWORD" ssh -v -o ConnectTimeout=5 \
        -o PreferredAuthentications=password \
        -o PubkeyAuthentication=no \
        -o StrictHostKeyChecking=no \
        "$VM_USERNAME@$vm_ip" "echo SSH connection successful" 2>&1; then
        
        echo >&2
        echo "SSH connection failed. Please verify on the VM:" >&2
        echo "1. SSH service is running:" >&2
        echo "   sudo systemctl status ssh" >&2
        echo >&2
        echo "2. Password authentication is enabled:" >&2
        echo "   sudo sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config" >&2
        echo "   sudo sed -i 's/PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config" >&2
        echo "   sudo systemctl restart ssh" >&2
        echo >&2
        echo "3. Your username ($VM_USERNAME) exists and has a home directory:" >&2
        echo "   id $VM_USERNAME" >&2
        echo "   ls -ld /home/$VM_USERNAME" >&2
        echo "   sudo mkdir -p /home/$VM_USERNAME" >&2
        echo "   sudo chown $VM_USERNAME:$VM_USERNAME /home/$VM_USERNAME" >&2
        echo >&2
        echo "4. Your password is correct:" >&2
        echo "   sudo passwd $VM_USERNAME  # to reset password if needed" >&2
        return 1
    fi
    
    return 0
}

wait_for_ssh() {
    local vm_ip="$1"
    local max_attempts=12  # 2 minutes total (12 * 10 seconds)
    local attempt=1
    
    echo "Checking for SSH server on ${vm_ip}..." >&2
    
    # First check if port 22 is open
    local port_attempts=6  # 30 seconds for port check
    local port_attempt=1
    
    while [ $port_attempt -le $port_attempts ]; do
        if nc -z -w 5 "$vm_ip" 22; then
            break
        fi
        echo "Attempt $port_attempt/$port_attempts - SSH port not open yet..." >&2
        if [ $port_attempt -eq $port_attempts ]; then
            echo "SSH port (22) is not open on ${vm_ip}" >&2
            echo "Please ensure openssh-server is installed and running on the VM:" >&2
            echo "  1. Open terminal in the VM" >&2
            echo "  2. Run: sudo apt update" >&2
            echo "  3. Run: sudo apt install -y openssh-server" >&2
            echo "  4. Run: sudo systemctl enable ssh" >&2
            echo "  5. Run: sudo systemctl start ssh" >&2
            return 1
        fi
        sleep 5
        ((port_attempt++))
    done
    
    echo "SSH port is open, checking service availability..." >&2
    
    while [ $attempt -le $max_attempts ]; do
        if check_ssh_config "$vm_ip"; then
            echo "SSH service is available and accepting connections" >&2
            return 0
        fi
        echo "Attempt $attempt/$max_attempts - SSH service not ready yet..." >&2
        sleep 10
        ((attempt++))
    done
    
    echo "Timed out waiting for SSH service on ${vm_ip}" >&2
    return 1
}
