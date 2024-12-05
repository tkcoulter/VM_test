#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$(dirname "$(readlink -f "$0")")"

# Source common functions with full path
source "${SCRIPT_DIR}/vm_functions.sh"

print_usage() {
    echo "Usage: sudo $0 [desktop|live]"
    echo
    echo "This script restores a VM from a previously created backup."
    echo
    echo "Arguments:"
    echo "  desktop    Restore an Ubuntu Desktop VM backup"
    echo "  live       Restore an Ubuntu Server VM backup"
    echo
    echo "Examples:"
    echo "  1. Restore a desktop VM:"
    echo "     sudo ./restore_vm.sh desktop"
    echo
    echo "  2. Restore a server VM:"
    echo "     sudo ./restore_vm.sh live"
    echo
    echo "Note: You must have created backups using backup_vms.sh before using this script."
    echo "      The restored VM will be created with a unique timestamp-based name to avoid conflicts."
    echo
    echo "Related commands:"
    echo "  Create backup:  sudo ./backup_vms.sh"
    echo "  Clear backups:  sudo ./clear_backups.sh"
}

# Check for root privileges
if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo privileges"
    echo
    print_usage
    exit 1
fi

# Check arguments
if [ $# -lt 1 ]; then
    print_usage
    exit 1
fi

VM_TYPE="$1"
if [[ "$VM_TYPE" != "desktop" && "$VM_TYPE" != "live" ]]; then
    echo "Error: VM type must be either 'desktop' or 'live'"
    echo
    print_usage
    exit 1
fi

# Setup base directories
VM_BASE=$(setup_directories)
if [ $? -ne 0 ]; then
    echo "Error: Failed to setup directories"
    exit 1
fi

BACKUP_BASE="${VM_BASE}/backups"

# Check if backups exist
if [ ! -d "$BACKUP_BASE" ]; then
    echo "Error: No backups found in ${BACKUP_BASE}"
    echo "Please run sudo ./backup_vms.sh first to create backups of your running VMs."
    exit 1
fi

# List available backup directories
echo "=== Available Backup Directories ==="
echo "Each directory contains backups from a specific backup session"
echo "Format: YYYYMMDD_HHMMSS (timestamp when backup was created)"
echo

BACKUP_DIRS=($(ls -d ${BACKUP_BASE}/*/ 2>/dev/null))
if [ ${#BACKUP_DIRS[@]} -eq 0 ]; then
    echo "No backup directories found"
    echo "Please run sudo ./backup_vms.sh first to create backups of your running VMs."
    exit 1
fi

# Display backup directories with index
for i in "${!BACKUP_DIRS[@]}"; do
    echo "[$i] $(basename ${BACKUP_DIRS[$i]})"
done

# Get user selection for backup directory
echo
echo "Please select a backup directory by entering its number"
read -p "Select backup directory [0-$((${#BACKUP_DIRS[@]}-1))]: " DIR_INDEX

if ! [[ "$DIR_INDEX" =~ ^[0-9]+$ ]] || [ "$DIR_INDEX" -ge "${#BACKUP_DIRS[@]}" ]; then
    echo "Error: Invalid selection"
    echo "Please enter a number between 0 and $((${#BACKUP_DIRS[@]}-1))"
    exit 1
fi

SELECTED_DIR="${BACKUP_DIRS[$DIR_INDEX]}"

# List available VM backups of selected type
echo
echo "=== Available ${VM_TYPE^} VM Backups ==="
echo "Listing backups from directory: $(basename ${SELECTED_DIR})"
echo

# Updated pattern to match both old and new naming schemes
BACKUPS=($(ls "${SELECTED_DIR}"ubuntu-${VM_TYPE}-*.qcow2 2>/dev/null))
if [ ${#BACKUPS[@]} -eq 0 ]; then
    echo "No ${VM_TYPE} VM backups found in selected directory"
    echo "Try selecting a different backup directory or create new backups using:"
    echo "sudo ./backup_vms.sh"
    exit 1
fi

# Display backups with index
for i in "${!BACKUPS[@]}"; do
    echo "[$i] $(basename ${BACKUPS[$i]})"
done

# Get user selection for backup file
echo
echo "Please select a backup file by entering its number"
read -p "Select backup to restore [0-$((${#BACKUPS[@]}-1))]: " BACKUP_INDEX

if ! [[ "$BACKUP_INDEX" =~ ^[0-9]+$ ]] || [ "$BACKUP_INDEX" -ge "${#BACKUPS[@]}" ]; then
    echo "Error: Invalid selection"
    echo "Please enter a number between 0 and $((${#BACKUPS[@]}-1))"
    exit 1
fi

SELECTED_BACKUP="${BACKUPS[$BACKUP_INDEX]}"

# Restore the VM
if restore_vm "$SELECTED_BACKUP" "$VM_TYPE" "$VM_BASE"; then
    echo
    echo "=== Restoration Complete ==="
    echo "Your VM has been successfully restored!"
    echo
    echo "To access the restored VM:"
    echo "1. Run: virt-manager"
    echo "2. Look for the VM with a unique timestamp-based name"
    echo
    echo "Note: The original backup remains unchanged and can be used for future restores."
    echo
    echo "Additional commands:"
    echo "- Create new backup:  sudo ./backup_vms.sh"
    echo "- Clear all backups:  sudo ./clear_backups.sh"
    exit 0
else
    echo "Error: VM restoration failed"
    exit 1
fi
