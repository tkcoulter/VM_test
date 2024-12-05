#!/bin/bash

# Source common functions
source "$(dirname "$0")/vm_functions.sh"

if [ "$EUID" -ne 0 ]; then
    echo "Error: This script must be run with sudo privileges"
    echo "Usage: sudo $0"
    exit 1
fi

# Setup base directories
VM_BASE=$(setup_directories)
BACKUP_DIR="${VM_BASE}/backups"

if [ ! -d "$BACKUP_DIR" ]; then
    echo "No backup directory found at ${BACKUP_DIR}"
    exit 0
fi

echo "This will delete ALL VM backups in ${BACKUP_DIR}"
read -p "Are you sure you want to continue? (y/N) " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Operation cancelled"
    exit 1
fi

echo "Removing all VM backups..."

# Count files before deletion
TOTAL_BACKUPS=$(find "$BACKUP_DIR" -type f -name "*.qcow2" | wc -l)
TOTAL_DIRS=$(find "$BACKUP_DIR" -mindepth 1 -type d | wc -l)

# Remove all backup directories and their contents
rm -rf "${BACKUP_DIR:?}"/*

# Recreate the backup directory to ensure it exists for future backups
mkdir -p "$BACKUP_DIR"
chown libvirt-qemu:libvirt-qemu "$BACKUP_DIR"

echo "Cleanup complete!"
echo "Removed $TOTAL_BACKUPS backup files from $TOTAL_DIRS backup directories"
