#!/bin/bash

# Functions for VM backup and restore operations

create_backup_directories() {
    local vm_base="$1"
    local timestamp="${2:-$(date +%Y%m%d_%H%M%S)}"
    local backup_dir="${vm_base}/backups/${timestamp}"
    
    mkdir -p "$backup_dir"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create backup directory: $backup_dir" >&2
        return 1
    fi
    
    chown libvirt-qemu:libvirt-qemu "$backup_dir"
    echo "$backup_dir"
}

verify_vm_running() {
    local vm_name="$1"
    if ! virsh domstate "$vm_name" | grep -q "running"; then
        echo "Error: VM '$vm_name' is not running" >&2
        return 1
    fi
    return 0
}

get_vm_disk_path() {
    local vm_name="$1"
    local disk_path
    
    disk_path=$(virsh domblklist "$vm_name" | grep -v "Source" | grep "^.*qcow2" | awk '{print $2}')
    if [ -z "$disk_path" ]; then
        echo "Error: No qcow2 disk found for VM: $vm_name" >&2
        return 1
    fi
    if [ ! -f "$disk_path" ]; then
        echo "Error: Disk file not found: $disk_path" >&2
        return 1
    fi
    echo "$disk_path"
}

create_vm_snapshot() {
    local vm_name="$1"
    local snapshot_name="$2"
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Creating snapshot for VM '$vm_name' (attempt $attempt/$max_attempts)..." >&2
        if virsh snapshot-create-as "$vm_name" "$snapshot_name" \
            "Temporary snapshot for backup" --disk-only --atomic; then
            return 0
        fi
        echo "Snapshot creation failed, retrying..." >&2
        sleep 2
        ((attempt++))
    done
    
    echo "Error: Failed to create snapshot after $max_attempts attempts" >&2
    return 1
}

remove_vm_snapshot() {
    local vm_name="$1"
    local snapshot_name="$2"
    local max_attempts=3
    local attempt=1
    
    while [ $attempt -le $max_attempts ]; do
        echo "Removing snapshot for VM '$vm_name' (attempt $attempt/$max_attempts)..." >&2
        if virsh snapshot-delete "$vm_name" "$snapshot_name" --metadata; then
            return 0
        fi
        echo "Snapshot removal failed, retrying..." >&2
        sleep 2
        ((attempt++))
    done
    
    echo "Error: Failed to remove snapshot after $max_attempts attempts" >&2
    return 1
}

backup_vm() {
    local vm_name="$1"
    local backup_dir="$2"
    local snapshot_name="backup_snapshot_$(date +%s)"
    local success=false
    
    echo "Starting backup process for VM: $vm_name" >&2
    
    # Verify VM is running
    if ! verify_vm_running "$vm_name"; then
        return 1
    fi
    
    # Get disk path
    local disk_path
    disk_path=$(get_vm_disk_path "$vm_name")
    if [ $? -ne 0 ]; then
        return 1
    fi
    
    # Create backup filename
    local backup_name="${vm_name}_$(date +%Y%m%d_%H%M%S).qcow2"
    local backup_path="${backup_dir}/${backup_name}"
    
    echo "Creating backup of disk: $disk_path" >&2
    echo "Backup location: $backup_path" >&2
    
    # Create snapshot
    if create_vm_snapshot "$vm_name" "$snapshot_name"; then
        # Copy disk image
        if cp "$disk_path" "$backup_path"; then
            chown libvirt-qemu:libvirt-qemu "$backup_path"
            success=true
            echo "Successfully created backup for VM: $vm_name" >&2
        else
            echo "Error: Failed to copy disk image for VM: $vm_name" >&2
        fi
        
        # Always try to remove the snapshot
        remove_vm_snapshot "$vm_name" "$snapshot_name"
    fi
    
    if [ "$success" = true ]; then
        return 0
    else
        return 1
    fi
}

restore_vm() {
    local backup_path="$1"
    local vm_type="$2"
    local vm_base="$3"
    
    if [ ! -f "$backup_path" ]; then
        echo "Error: Backup file not found: $backup_path" >&2
        return 1
    fi
    
    # Extract version from backup filename (assuming format contains version like 24.04)
    local version
    if [[ $backup_path =~ ([0-9]+\.[0-9]+) ]]; then
        version="${BASH_REMATCH[1]}"
    else
        version="24.04"  # Default to 24.04 if version not found in filename
    fi

    # Use the same naming convention as test_vm.sh
    local new_vm_name="ubuntu-test-${vm_type}-${version}"
    local vm_dir="${vm_base}/images"
    local new_disk_path="${vm_dir}/ubuntu-${vm_type}-${version}.qcow2"
    
    echo "=== Restoring VM Backup ===" >&2
    echo "Source backup: $(basename ${backup_path})" >&2
    echo "New VM name: ${new_vm_name}" >&2
    echo "New disk path: ${new_disk_path}" >&2
    echo
    
    # Copy backup to images directory
    echo "Step 1/3: Copying backup file..." >&2
    if ! cp "$backup_path" "$new_disk_path"; then
        echo "Error: Failed to copy backup file" >&2
        return 1
    fi
    chown libvirt-qemu:libvirt-qemu "$new_disk_path"
    
    # Setup network
    echo "Step 2/3: Setting up network..." >&2
    if ! setup_network; then
        echo "Error: Failed to setup network" >&2
        rm -f "$new_disk_path"
        return 1
    fi
    
    # Create new VM from backup
    echo "Step 3/3: Creating new VM..." >&2
    if ! virt-install \
        --name "$new_vm_name" \
        --memory 4096 \
        --vcpus 2 \
        --disk path="$new_disk_path",format=qcow2,bus=virtio \
        --import \
        --os-variant ubuntu22.04 \
        --network network=default,model=virtio \
        --graphics vnc,listen=0.0.0.0 \
        --boot uefi \
        --noautoconsole; then
        
        echo "Error: Failed to create new VM" >&2
        rm -f "$new_disk_path"
        return 1
    fi
    
    echo "VM restored successfully as: $new_vm_name" >&2
    echo "This VM follows the test_vm.sh naming convention and can be managed by clear_vms.sh" >&2
    return 0
}