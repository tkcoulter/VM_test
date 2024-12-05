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
#    sudo ./vm_tests/test_vm.sh [desktop|live] [version]
#
# Examples:
#    sudo ./vm_tests/test_vm.sh desktop 24.04
#    sudo ./vm_tests/test_vm.sh live 24.04
#
# Requirements:
#    sudo apt install -y virt-manager libvirt-daemon-system virtinst

# Check if running with sudo
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo privileges"
    echo "Usage: sudo $0 [desktop|live] [version]"
    exit 1
fi

# Check if both parameters are provided
if [ $# -lt 2 ]; then
    echo "Usage: sudo $0 [desktop|live] [version]"
    echo "Example: sudo $0 desktop 24.04"
    echo "Example: sudo $0 live 24.04"
    exit 1
fi

ISO_TYPE="$1"
VERSION="$2"

# Get the directory where this script is located
SCRIPT_DIR="$(dirname "$0")"

# Make all scripts executable
chmod +x "${SCRIPT_DIR}/vm_functions.sh"
chmod +x "${SCRIPT_DIR}/install_desktop.sh"
chmod +x "${SCRIPT_DIR}/install_live.sh"

# Call the appropriate installation script based on type
if [ "$ISO_TYPE" = "desktop" ]; then
    exec "${SCRIPT_DIR}/install_desktop.sh" "$VERSION"
elif [ "$ISO_TYPE" = "live" ]; then
    exec "${SCRIPT_DIR}/install_live.sh" "$VERSION"
else
    echo "Error: Invalid ISO type. Use 'desktop' or 'live'"
    exit 1
fi
