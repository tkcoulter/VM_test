#!/bin/bash

# Functions for file copying and related utilities

format_duration() {
    local seconds=$1
    local minutes=$((seconds / 60))
    local remaining_seconds=$((seconds % 60))
    if [ $minutes -gt 0 ]; then
        echo "${minutes}m ${remaining_seconds}s"
    else
        echo "${seconds}s"
    fi
}

copy_setup_files() {
    local vm_ip="$1"
    local setup_path="${DEFAULT_SETUP_PATH}"
    local dest_dir="/home/$VM_USERNAME"
    
    echo "Copying setup contents to VM at ${vm_ip}..." >&2
    
    # Get directory size for progress information
    local dir_size=$(du -sh "$setup_path" 2>/dev/null | cut -f1)
    echo "Total size to copy: ${dir_size}" >&2
    
    # First ensure the destination directory exists and is writable
    echo "Verifying destination directory..." >&2
    if ! sshpass -p "$VM_PASSWORD" ssh -o PreferredAuthentications=password \
        -o PubkeyAuthentication=no \
        -o StrictHostKeyChecking=no \
        "$VM_USERNAME@$vm_ip" "mkdir -p $dest_dir && touch $dest_dir/.write_test && rm $dest_dir/.write_test" 2>&1; then
        echo "Failed to verify/create destination directory" >&2
        echo "Please ensure $dest_dir exists and is writable by $VM_USERNAME" >&2
        return 1
    fi
    
    # Record start time
    local start_time=$(date +%s)
    
    echo "Starting file copy..." >&2
    # Try to copy with a timeout and show all output
    if ! timeout 60 sshpass -p "$VM_PASSWORD" scp -r \
        -o PreferredAuthentications=password \
        -o PubkeyAuthentication=no \
        -o StrictHostKeyChecking=no \
        "${setup_path}" "$VM_USERNAME@$vm_ip:$dest_dir/" 2>&1; then
        
        local copy_status=$?
        # Calculate duration
        local end_time=$(date +%s)
        local duration=$((end_time - start_time))
        local formatted_duration=$(format_duration $duration)
        
        echo "Failed to copy setup files to ${vm_ip} (after ${formatted_duration})" >&2
        if [ $copy_status -eq 124 ]; then
            echo "Copy operation timed out" >&2
        fi
        return 1
    fi
    
    # Calculate duration
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    local formatted_duration=$(format_duration $duration)
    
    echo "Successfully copied setup files to ${vm_ip} (took ${formatted_duration})" >&2
    
    # Verify the files were copied
    echo "Verifying copied files..." >&2
    if sshpass -p "$VM_PASSWORD" ssh -o PreferredAuthentications=password \
        -o PubkeyAuthentication=no \
        -o StrictHostKeyChecking=no \
        "$VM_USERNAME@$vm_ip" "ls -l $dest_dir/setup_ansible_host" 2>&1; then
        echo "Files verified successfully" >&2
        return 0
    else
        echo "Failed to verify copied files" >&2
        return 1
    fi
}

copy_setup_to_all_vms() {
    local setup_path="${DEFAULT_SETUP_PATH}"
    local success_count=0
    local fail_count=0
    local total_duration=0
    
    # Check if sshpass is installed
    if ! command -v sshpass >/dev/null 2>&1; then
        echo "Installing sshpass..." >&2
        apt-get update >/dev/null
        apt-get install -y sshpass >/dev/null
    fi
    
    echo "Starting setup files distribution to all running VMs..." >&2
    
    # Get directory size for information
    local dir_size=$(du -sh "$setup_path" 2>/dev/null | cut -f1)
    echo "Total size to copy per VM: ${dir_size}" >&2
    echo
    
    # Record overall start time
    local overall_start=$(date +%s)
    
    # Get list of running VMs
    local running_vms=$(virsh list --name)
    if [ -z "$running_vms" ]; then
        echo "No running VMs found" >&2
        return 1
    fi
    
    echo "Found running VMs:" >&2
    echo "$running_vms" >&2
    echo
    
    # Process each VM
    while IFS= read -r vm_name; do
        [ -z "$vm_name" ] && continue
        
        echo "Processing VM: $vm_name" >&2
        
        # Get VM IP
        local vm_ip=$(wait_for_vm_ip "$vm_name")
        if [ -z "$vm_ip" ]; then
            echo "Failed to get IP for VM: $vm_name" >&2
            ((fail_count++))
            continue
        fi
        
        echo "VM IP: $vm_ip" >&2
        
        # Wait for SSH to be available (with timeout)
        if ! wait_for_ssh "$vm_ip"; then
            echo "Skipping VM $vm_name due to SSH issues" >&2
            ((fail_count++))
            continue
        fi
        
        # Record start time for this VM
        local vm_start=$(date +%s)
        
        # Copy files
        if copy_setup_files "$vm_ip"; then
            ((success_count++))
        else
            ((fail_count++))
        fi
        
        # Calculate duration for this VM
        local vm_end=$(date +%s)
        local vm_duration=$((vm_end - vm_start))
        total_duration=$((total_duration + vm_duration))
        
        echo
    done <<< "$running_vms"
    
    # Calculate overall duration
    local overall_end=$(date +%s)
    local overall_duration=$((overall_end - overall_start))
    local formatted_overall=$(format_duration $overall_duration)
    
    # Calculate average duration for successful copies
    local avg_duration=0
    if [ $success_count -gt 0 ]; then
        avg_duration=$((total_duration / success_count))
    fi
    local formatted_avg=$(format_duration $avg_duration)
    
    # Print summary
    echo "=== Copy Operation Summary ===" >&2
    echo "Total VMs processed: $((success_count + fail_count))" >&2
    echo "Successful copies: $success_count" >&2
    echo "Failed copies: $fail_count" >&2
    echo "Total time: ${formatted_overall}" >&2
    if [ $success_count -gt 0 ]; then
        echo "Average copy time per VM: ${formatted_avg}" >&2
    fi
    
    # Return success if at least one copy succeeded
    [ $success_count -gt 0 ]
}
