#!/bin/bash

# Functions for displaying information and instructions

print_vm_info() {
    local vm_name="$1"
    local vm_ip="$2"
    local vm_type="$3"
    
    echo "=============================================" >&2
    echo "VM is now running!" >&2
    echo "VM IP address: $vm_ip" >&2
    echo "" >&2
    echo "To access the VM:" >&2
    echo "1. Using virt-manager GUI:" >&2
    echo "   Run: virt-manager" >&2
    echo "   Then double-click on '$vm_name'" >&2
    echo "" >&2
    echo "2. Using SSH (once OS is installed):" >&2
    if [ "$vm_type" = "desktop" ]; then
        echo "Note: For SSH access, run these commands in the VM:" >&2
        echo "   sudo apt update" >&2
        echo "   sudo apt install -y openssh-server" >&2
        echo "   sudo systemctl enable ssh" >&2
        echo "   sudo systemctl start ssh" >&2
        echo "   sudo sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config" >&2
        echo "   sudo sed -i 's/PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config" >&2
        echo "   sudo systemctl restart ssh" >&2
    fi
    echo "SSH command: ssh $VM_USERNAME@$vm_ip" >&2
    echo "=============================================" >&2
    echo "Note: On first SSH connection you may need to accept the host key" >&2
    echo "To reset all VMs to a fresh state, run: sudo ./setup_ansible_host/vm_tests/clear_vms.sh" >&2
}

print_ssh_instructions() {
    echo "=== SSH Server Setup Instructions ==="
    echo "If SSH connection fails, you need to install openssh-server on each VM:"
    echo
    echo "1. For Ubuntu Desktop VMs:"
    echo "   - Open terminal in the VM"
    echo "   - Run: sudo apt update"
    echo "   - Run: sudo apt install -y openssh-server"
    echo "   - Run: sudo systemctl enable ssh"
    echo "   - Run: sudo systemctl start ssh"
    echo "   - Run: sudo sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config"
    echo "   - Run: sudo sed -i 's/PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config"
    echo "   - Run: sudo systemctl restart ssh"
    echo
    echo "2. For Ubuntu Server VMs:"
    echo "   SSH server should be installed by default if you selected it during installation"
    echo "   If not, follow the same steps as Desktop VMs"
    echo
    echo "3. Ensure your user has a home directory:"
    echo "   - The user must exist and have a valid home directory"
    echo "   - Run: sudo mkdir -p /home/YOUR_USERNAME"
    echo "   - Run: sudo chown YOUR_USERNAME:YOUR_USERNAME /home/YOUR_USERNAME"
    echo
    echo "After installing SSH server, run this script again."
    echo "================================================"
}
