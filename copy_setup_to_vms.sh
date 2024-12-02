#!/bin/bash

# Default configuration - set these variables to skip prompts
DEFAULT_VM_USERNAME="ubuntu"
DEFAULT_VM_PASSWORD="ubuntu"
DEFAULT_SETUP_PATH="/home/ubuntu2/Documents/cloudstack_ubuntu_ansible/install_remote_host"

# Source common functions
source "$(dirname "$0")/vm_functions.sh"

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

if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo privileges"
    echo "Usage: sudo $0"
    exit 1
fi

# Install sshpass if not present
if ! command -v sshpass >/dev/null 2>&1; then
    echo "Installing sshpass..."
    apt-get update >/dev/null
    if ! apt-get install -y sshpass >/dev/null; then
        echo "Error: Failed to install sshpass"
        exit 1
    fi
    echo "sshpass installed successfully"
fi

# Get VM username - use DEFAULT_VM_USERNAME if set, otherwise prompt
if [ -n "$DEFAULT_VM_USERNAME" ]; then
    VM_USERNAME="$DEFAULT_VM_USERNAME"
    echo "Using default username: $VM_USERNAME"
else
    read -p "Enter VM username (default: ubuntu): " VM_USERNAME
    VM_USERNAME=${VM_USERNAME:-ubuntu}
fi

# Get VM password - use DEFAULT_VM_PASSWORD if set, otherwise prompt
if [ -n "$DEFAULT_VM_PASSWORD" ]; then
    VM_PASSWORD="$DEFAULT_VM_PASSWORD"
    echo "Using default password"
else
    read -s -p "Enter VM password: " VM_PASSWORD
    echo
fi

if [ -z "$VM_PASSWORD" ]; then
    echo "Error: Password cannot be empty"
    exit 1
fi

# Export variables for use in functions
export VM_USERNAME
export VM_PASSWORD
export DEFAULT_SETUP_PATH

echo
echo "=== Copying Setup Files to All Running VMs ==="
echo "This will copy $DEFAULT_SETUP_PATH to all running VMs"
echo "Any existing files will be overwritten"
echo
echo "Will connect using username: $VM_USERNAME"
echo "Note: Each VM must have SSH server installed and running"
print_ssh_instructions
echo

read -p "Continue with copy operation? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled"
    exit 1
fi

copy_setup_to_all_vms
