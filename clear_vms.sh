#!/bin/bash

echo "Stopping and removing VMs..."

# Function to thoroughly clean up a VM
cleanup_vm() {
    local vm_name="$1"
    local vm_type="$2"
    local version="$3"
    local timestamp="$4"
    local vm_base="/var/lib/libvirt"
    local vm_img="${vm_base}/images/${vm_name}.qcow2"
    local max_attempts=30
    local attempt=0
    local backup_dir="${vm_base}/backups"

    echo "Cleaning up VM: $vm_name"

    # Remove any existing snapshots first
    if virsh list --all | grep -q "$vm_name"; then
        echo "Removing any existing snapshots..."
        virsh snapshot-list "$vm_name" --name 2>/dev/null | while read snap; do
            if [ ! -z "$snap" ]; then
                echo "Removing snapshot: $snap"
                virsh snapshot-delete "$vm_name" "$snap" --metadata 2>/dev/null || true
            fi
        done
    fi

    # Force stop the VM if it's running
    if virsh list --all | grep -q "$vm_name"; then
        echo "Force stopping VM $vm_name..."
        virsh destroy "$vm_name" 2>/dev/null || true
        
        # Wait for VM to fully stop with timeout
        attempt=0
        while virsh domstate "$vm_name" 2>/dev/null | grep -q "running"; do
            echo "Waiting for VM to stop..."
            sleep 2
            ((attempt++))
            if [ $attempt -ge $max_attempts ]; then
                echo "Warning: Timeout waiting for VM to stop. Proceeding with cleanup..."
                break
            fi
        done
    fi

    # Clean up any network interfaces associated with the VM
    echo "Cleaning up network interfaces..."
    virsh domiflist "$vm_name" 2>/dev/null | grep -v "Interface" | awk '{print $1}' | while read iface; do
        if [ ! -z "$iface" ]; then
            echo "Detaching interface: $iface"
            virsh detach-interface "$vm_name" --type network --current 2>/dev/null || true
        fi
    done

    # Force undefine the VM with all possible options
    if virsh list --all | grep -q "$vm_name"; then
        echo "Force removing VM definition for $vm_name..."
        virsh undefine "$vm_name" --managed-save --remove-all-storage --snapshots-metadata --nvram 2>/dev/null || true
        
        # Wait for VM to be undefined with timeout
        attempt=0
        while virsh list --all | grep -q "$vm_name"; do
            echo "Waiting for VM to be undefined..."
            sleep 2
            ((attempt++))
            if [ $attempt -ge $max_attempts ]; then
                echo "Warning: Timeout waiting for VM to be undefined. Proceeding with cleanup..."
                break
            fi
        done
    fi

    # Clean up storage pools (excluding backup pool)
    echo "Cleaning up storage pools..."
    virsh pool-list --all | grep -v "Name.*State" | awk '{print $1}' | while read pool; do
        # Skip if this is the backup pool
        if [[ "$pool" == *"backup"* ]]; then
            continue
        fi
        if virsh vol-list "$pool" 2>/dev/null | grep -q "$vm_name"; then
            echo "Cleaning up volumes in pool: $pool"
            virsh vol-list "$pool" | grep "$vm_name" | awk '{print $1}' | while read vol; do
                echo "Removing volume: $vol from pool: $pool"
                virsh vol-delete "$vol" "$pool" 2>/dev/null || true
            done
        fi
    done

    # Force remove all associated files
    echo "Force removing all associated files..."

    # Remove disk image
    if [ -f "$vm_img" ]; then
        echo "Removing disk image: $vm_img"
        rm -f "$vm_img"
    fi

    # Remove NVRAM files
    local nvram_pattern="/var/lib/libvirt/qemu/nvram/${vm_name}*.fd"
    if ls $nvram_pattern 1> /dev/null 2>&1; then
        echo "Removing NVRAM files matching: $nvram_pattern"
        rm -f $nvram_pattern
    fi

    # Remove autoinstall files for desktop
    if [ "$vm_type" = "desktop" ]; then
        local autoinstall_dir="${vm_base}/autoinstall"
        if [ -d "$autoinstall_dir" ]; then
            echo "Removing autoinstall directory: $autoinstall_dir"
            rm -rf "$autoinstall_dir"
        fi
    fi

    # Remove any leftover files in various libvirt directories
    local cleanup_dirs=(
        "/var/lib/libvirt/images"
        "/var/lib/libvirt/qemu/nvram"
        "/var/lib/libvirt/qemu/snapshot"
        "/var/lib/libvirt/qemu/save"
        "/var/lib/libvirt/qemu/domain"
        "/var/lib/libvirt/qemu/checkpoint"
    )

    for dir in "${cleanup_dirs[@]}"; do
        if [ -d "$dir" ]; then
            echo "Checking $dir for leftover files..."
            # Use -prune to exclude backup directory from search
            find "$dir" -path "${backup_dir}" -prune -o -name "*${vm_name}*" -exec rm -f {} \; 2>/dev/null || true
        fi
    done

    echo "Cleanup complete for $vm_name"
}

# Function to get all test VMs
get_test_vms() {
    # Get all VMs that match our patterns (both old and new format)
    virsh list --all | grep -E "ubuntu-(desktop|live)-[0-9]+\.[0-9]+" | awk '{print $2}' || true
}

echo "Identifying all VMs..."
test_vms=$(get_test_vms)

if [ -z "$test_vms" ]; then
    echo "No VMs found."
else
    echo "Found VMs:"
    echo "$test_vms"
    
    # Process each VM
    while IFS= read -r vm_name; do
        # Match both old and new format VM names
        if [[ "$vm_name" =~ ubuntu-(desktop|live)-([0-9.]+)(-[0-9]{8}_[0-9]{6})? ]]; then
            vm_type="${BASH_REMATCH[1]}"
            version="${BASH_REMATCH[2]}"
            timestamp="${BASH_REMATCH[3]}"
            cleanup_vm "$vm_name" "$vm_type" "$version" "$timestamp"
        fi
    done <<< "$test_vms"
fi

# Final verification
echo "Verifying cleanup..."

# Check for any remaining VMs
remaining_vms=$(virsh list --all | grep -E "ubuntu-(desktop|live)-[0-9]+\.[0-9]+" || true)
if [ ! -z "$remaining_vms" ]; then
    echo "Warning: Some VMs may still exist:"
    echo "$remaining_vms"
else
    echo "All VMs have been removed successfully"
fi

# Check for any remaining files, explicitly excluding backups directory
echo "Checking for remaining files (excluding backups)..."
find /var/lib/libvirt -path "/var/lib/libvirt/backups" -prune -o -type f -name "*ubuntu-*" -print 2>/dev/null || true

# Restart libvirtd to ensure clean state
echo "Restarting libvirtd service..."
systemctl restart libvirtd

echo "VM cleanup complete. The next run of test_vm.sh will create fresh VMs."
echo "Note: VM backups in /var/lib/libvirt/backups are preserved."
echo "Usage reminder for test_vm.sh:"
echo "  For desktop version: sudo ./test_vm.sh desktop 24.04"
echo "  For live version: sudo ./test_vm.sh live 24.04"
