#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"

# Source the VM functions
source "${SCRIPT_DIR}/vm_functions.sh"

usage() {
    echo "Usage: $0 <vm_name>"
    echo "Copies a running VM and boots the copy"
    echo
    echo "Arguments:"
    echo "  vm_name    Name of the running VM to copy"
    exit 1
}

cleanup_existing_snapshots() {
    local vm_name="$1"
    local snapshots
    
    # Get list of existing snapshots
    snapshots=$(virsh snapshot-list "$vm_name" --name 2>/dev/null)
    if [ -n "$snapshots" ]; then
        echo "Cleaning up existing snapshots..." >&2
        while IFS= read -r snapshot; do
            [ -z "$snapshot" ] && continue
            echo "Removing snapshot: $snapshot" >&2
            virsh snapshot-delete "$vm_name" "$snapshot" --metadata
        done <<< "$snapshots"
    fi
}

# Check arguments
if [ $# -ne 1 ]; then
    usage
fi

vm_name="$1"
vm_base="/var/lib/libvirt"
timestamp=$(date +%Y%m%d_%H%M%S)

# Verify VM is running
if ! verify_vm_running "$vm_name"; then
    exit 1
fi

# Clean up any existing snapshots
cleanup_existing_snapshots "$vm_name"

# Create backup directory
backup_dir=$(create_backup_directories "$vm_base" "$timestamp")
if [ $? -ne 0 ]; then
    echo "Error: Failed to create backup directory" >&2
    exit 1
fi

# Create backup of the VM
echo "Creating backup of VM: $vm_name" >&2
if ! backup_vm "$vm_name" "$backup_dir"; then
    echo "Error: Failed to create backup of VM" >&2
    exit 1
fi

# Get the backup file path
backup_file=$(ls "${backup_dir}"/*.qcow2 2>/dev/null | head -n 1)
if [ -z "$backup_file" ]; then
    echo "Error: Backup file not found" >&2
    exit 1
fi

# Determine VM type from original VM name
vm_type="desktop"
if [[ "$vm_name" =~ "live" ]]; then
    vm_type="live"
fi

# Create images directory if it doesn't exist
mkdir -p "/var/lib/libvirt/images"
chown libvirt-qemu:libvirt-qemu "/var/lib/libvirt/images"

# Restore the backup as a new VM
echo "Creating new VM from backup..." >&2
if ! restore_vm "$backup_file" "$vm_type" "$vm_base"; then
    echo "Error: Failed to create new VM from backup" >&2
    exit 1
fi

echo "Successfully copied and booted VM: $vm_name" >&2
exit 0
