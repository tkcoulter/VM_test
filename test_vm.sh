#!/bin/bash

# Usage Instructions:
# 1. From the root repository directory (/home/ubuntu2/Documents/cloudstack_ubuntu_ansible):
#    sudo chmod +x vm_tests/test_vm.sh
#    sudo chmod +x vm_tests/clear_vms.sh
#    sudo chmod +x vm_tests/install_desktop.sh
#    sudo chmod +x vm_tests/install_live.sh
#    sudo chmod +x vm_tests/vm_functions.sh
#
# 2. Run the script (also from root directory):
#    sudo ./vm_tests/test_vm.sh [desktop|live] [version] [name]
#
# Examples:
#    sudo ./vm_tests/test_vm.sh desktop 24.04           # Auto-generated name
#    sudo ./vm_tests/test_vm.sh desktop 24.04 my-vm     # Custom name
#    sudo ./vm_tests/test_vm.sh live 24.04              # Auto-generated name
#    sudo ./vm_tests/test_vm.sh live 24.04 server-vm    # Custom name
#
# Requirements:
#    sudo apt install -y virt-manager libvirt-daemon-system virtinst

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo privileges"
    echo "Usage: sudo $0 [desktop|live] [version] [name]"
    exit 1
fi

# Check if minimum parameters are provided
if [ $# -lt 2 ]; then
    echo "Usage: sudo $0 [desktop|live] [version] [name]"
    echo "Examples:"
    echo "  sudo $0 desktop 24.04           # Auto-generated name"
    echo "  sudo $0 desktop 24.04 my-vm     # Custom name"
    echo "  sudo $0 live 24.04              # Auto-generated name"
    echo "  sudo $0 live 24.04 server-vm    # Custom name"
    exit 1
fi

ISO_TYPE="$1"
VERSION="$2"
VM_NAME="$3"  # Optional parameter

# Get the directory where this script is located
SCRIPT_DIR="$(dirname "$0")"

# Make all scripts executable
chmod +x "${SCRIPT_DIR}/vm_functions.sh"
chmod +x "${SCRIPT_DIR}/install_desktop.sh"
chmod +x "${SCRIPT_DIR}/install_live.sh"

# Call the appropriate installation script based on type
if [ "$ISO_TYPE" = "desktop" ]; then
    if [ -n "$VM_NAME" ]; then
        exec "${SCRIPT_DIR}/install_desktop.sh" "$VERSION" "$VM_NAME"
    else
        exec "${SCRIPT_DIR}/install_desktop.sh" "$VERSION"
    fi
elif [ "$ISO_TYPE" = "live" ]; then
    if [ -n "$VM_NAME" ]; then
        exec "${SCRIPT_DIR}/install_live.sh" "$VERSION" "$VM_NAME"
    else
        exec "${SCRIPT_DIR}/install_live.sh" "$VERSION"
    fi
else
    echo "Error: Invalid ISO type. Use 'desktop' or 'live'"
    exit 1
fi
