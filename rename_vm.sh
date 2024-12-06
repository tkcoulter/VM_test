#!/bin/bash

# Source common functions
source "$(dirname "$0")/vm_functions.sh"

if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo privileges"
    echo "Usage: sudo $0 [old_name] [new_name]"
    exit 1
fi

if [ $# -ne 2 ]; then
    echo "Usage: sudo $0 [old_name] [new_name]"
    echo "Example: sudo $0 ubuntu-desktop-24.04-20241206 my-desktop-vm"
    exit 1
fi

OLD_NAME="$1"
NEW_NAME="$2"

# Ensure new name has ubuntu- prefix
if [[ "$NEW_NAME" != ubuntu-* ]]; then
    NEW_NAME="ubuntu-$NEW_NAME"
fi

# Check if old VM exists
if ! virsh dominfo "$OLD_NAME" >/dev/null 2>&1; then
    echo "Error: VM '$OLD_NAME' does not exist"
    exit 1
fi

# Check if new name already exists
if virsh dominfo "$NEW_NAME" >/dev/null 2>&1; then
    echo "Error: VM '$NEW_NAME' already exists"
    exit 1
fi

# Get VM state and disk path
VM_STATE=$(virsh domstate "$OLD_NAME")
DISK_PATH=$(virsh domblklist "$OLD_NAME" | awk 'NR>2 && $2!="-" {print $2; exit}')

if [ -z "$DISK_PATH" ]; then
    echo "Error: Could not find disk path for VM '$OLD_NAME'"
    exit 1
fi

# Generate new disk path
NEW_DISK_PATH=$(dirname "$DISK_PATH")/"$NEW_NAME".qcow2

echo "=== Renaming VM ==="
echo "Current name: $OLD_NAME"
echo "New name: $NEW_NAME"
echo "Current disk: $DISK_PATH"
echo "New disk: $NEW_DISK_PATH"
echo

# If VM is running, we need to shut it down gracefully
if [ "$VM_STATE" = "running" ]; then
    echo "VM is running. Shutting down gracefully..."
    virsh shutdown "$OLD_NAME"
    
    # Wait for VM to shut down (timeout after 60 seconds)
    TIMEOUT=60
    while [ $TIMEOUT -gt 0 ] && [ "$(virsh domstate "$OLD_NAME")" = "running" ]; do
        sleep 1
        ((TIMEOUT--))
    done
    
    if [ "$(virsh domstate "$OLD_NAME")" = "running" ]; then
        echo "Warning: VM did not shut down gracefully. Forcing shutdown..."
        virsh destroy "$OLD_NAME"
    fi
fi

# Rename the VM
echo "Renaming VM..."
if ! virsh dumpxml "$OLD_NAME" > /tmp/vm_config.xml; then
    echo "Error: Failed to dump VM configuration"
    exit 1
fi

# Update VM name and disk path in the XML
sed -i "s|<name>$OLD_NAME</name>|<name>$NEW_NAME</name>|g" /tmp/vm_config.xml
sed -i "s|$DISK_PATH|$NEW_DISK_PATH|g" /tmp/vm_config.xml

# Remove old VM (keeping disk)
if ! virsh undefine "$OLD_NAME" --nvram; then
    echo "Error: Failed to undefine old VM"
    exit 1
fi

# Rename disk file
echo "Renaming disk file..."
if ! mv "$DISK_PATH" "$NEW_DISK_PATH"; then
    echo "Error: Failed to rename disk file"
    exit 1
fi
chown libvirt-qemu:libvirt-qemu "$NEW_DISK_PATH"

# Define new VM
if ! virsh define /tmp/vm_config.xml; then
    echo "Error: Failed to define new VM"
    echo "Attempting to restore old VM..."
    mv "$NEW_DISK_PATH" "$DISK_PATH"
    virsh define /tmp/vm_config.xml
    exit 1
fi

# Clean up
rm /tmp/vm_config.xml

# Start VM if it was running before
if [ "$VM_STATE" = "running" ]; then
    echo "Starting renamed VM..."
    virsh start "$NEW_NAME"
fi

echo
echo "VM successfully renamed from '$OLD_NAME' to '$NEW_NAME'"
echo "You can manage the VM using:"
echo "  Start VM:    virsh start $NEW_NAME"
echo "  Stop VM:     virsh shutdown $NEW_NAME"
echo "  Delete VM:   virsh undefine $NEW_NAME --remove-all-storage"
echo "  Open GUI:    virt-manager"
