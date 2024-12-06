#!/bin/bash

# Source common functions
source "$(dirname "$0")/vm_functions.sh"

if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo privileges"
    echo "Usage: sudo $0 [version] [name]"
    exit 1
fi

if [ $# -lt 1 ]; then
    echo "Usage: sudo $0 [version] [name]"
    echo "Examples:"
    echo "  sudo $0 24.04           # Auto-generated name"
    echo "  sudo $0 24.04 my-vm     # Custom name"
    exit 1
fi

# Check and install required packages
echo "Checking and installing required packages..."
REQUIRED_PACKAGES="virt-manager libvirt-daemon-system virtinst cloud-image-utils"
for package in $REQUIRED_PACKAGES; do
    if ! dpkg -l | grep -q "^ii  $package "; then
        apt-get install -y "$package"
    fi
done

VERSION="$1"
CUSTOM_NAME="$2"  # Optional parameter
ISO_NAME="ubuntu-${VERSION}.1-desktop-amd64.iso"

# Setup directories and get base path
VM_BASE=$(setup_directories)
ISO_DIR="${VM_BASE}/iso"
VM_DIR="${VM_BASE}/images"

# Setup network
setup_network

# Download ISO
ISO_PATH=$(download_iso "$ISO_DIR" "$VERSION" "$ISO_NAME")
if [ $? -ne 0 ]; then
    exit 1
fi

# Create disk and get unique VM name
if [ -n "$CUSTOM_NAME" ]; then
    DISK_INFO=$(create_disk "$VM_DIR" "desktop" "$VERSION" "$CUSTOM_NAME")
else
    DISK_INFO=$(create_disk "$VM_DIR" "desktop" "$VERSION")
fi

if [ $? -ne 0 ]; then
    echo "Error: Failed to create disk"
    exit 1
fi

VM_IMG_PATH=$(echo "$DISK_INFO" | cut -d'|' -f1)
VM_NAME=$(echo "$DISK_INFO" | cut -d'|' -f2)

# Create and start the VM
echo "Creating and starting VM with name: $VM_NAME"
virt-install \
    --name "$VM_NAME" \
    --memory 4096 \
    --vcpus 2 \
    --disk path="$VM_IMG_PATH",format=qcow2,bus=virtio \
    --cdrom "$ISO_PATH" \
    --os-variant ubuntu22.04 \
    --network network=default,model=virtio \
    --graphics spice,listen=0.0.0.0 \
    --boot uefi \
    --noautoconsole

echo "VM creation started!"
echo "You can access the VM using virt-manager to complete the installation"
echo "Run: virt-manager"
