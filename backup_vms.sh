#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Source common functions with full path
source "${SCRIPT_DIR}/vm_functions.sh"

if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo privileges"
    echo "Usage: sudo $0"
    exit 1
fi

# Setup base directories
VM_BASE=$(setup_directories)
if [ $? -ne 0 ]; then
    echo "Error: Failed to setup directories"
    exit 1
fi

# Create backup directory with timestamp
BACKUP_DIR=$(create_backup_directories "$VM_BASE")
if [ $? -ne 0 ]; then
    echo "Error: Failed to create backup directory"
    exit 1
fi

echo "Creating VM backups in: $BACKUP_DIR"

# Get list of running VMs
RUNNING_VMS=$(virsh list --name)
if [ -z "$RUNNING_VMS" ]; then
    echo "No running VMs found."
    exit 0
fi

# Track backup results
TOTAL_VMS=0
SUCCESSFUL_BACKUPS=0
FAILED_BACKUPS=0

# Backup each running VM
while IFS= read -r VM; do
    [ -z "$VM" ] && continue
    ((TOTAL_VMS++))
    
    echo
    echo "=== Processing VM: $VM ==="
    if backup_vm "$VM" "$BACKUP_DIR"; then
        ((SUCCESSFUL_BACKUPS++))
    else
        ((FAILED_BACKUPS++))
        echo "Warning: Backup failed for VM: $VM"
    fi
done <<< "$RUNNING_VMS"

echo
echo "=== Backup Summary ==="
echo "Total VMs processed: $TOTAL_VMS"
echo "Successful backups: $SUCCESSFUL_BACKUPS"
echo "Failed backups: $FAILED_BACKUPS"
echo "Backup directory: $BACKUP_DIR"

# Return success only if all backups succeeded
[ $FAILED_BACKUPS -eq 0 ]
