#!/bin/bash

# Get the directory where this script is located
SCRIPT_DIR="$(dirname "${BASH_SOURCE[0]}")"
FUNCTIONS_DIR="${SCRIPT_DIR}/functions"

# Make all function files executable
chmod +x "${FUNCTIONS_DIR}"/*.sh

# Source all function files
for func_file in "${FUNCTIONS_DIR}"/*.sh; do
    if [ -f "$func_file" ]; then
        source "$func_file"
        if [ $? -ne 0 ]; then
            echo "Error: Failed to source $func_file" >&2
            exit 1
        fi
    fi
done

# Export functions that need to be available to other scripts
export -f setup_directories
export -f setup_network
export -f download_iso
export -f create_disk
export -f wait_for_vm_ip
export -f check_ssh_config
export -f wait_for_ssh
export -f format_duration
export -f copy_setup_files
export -f copy_setup_to_all_vms
export -f print_vm_info
export -f print_ssh_instructions
export -f create_backup_directories
export -f verify_vm_running
export -f get_vm_disk_path
export -f create_vm_snapshot
export -f remove_vm_snapshot
export -f backup_vm
export -f restore_vm
