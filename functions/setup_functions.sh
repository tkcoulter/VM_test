#!/bin/bash

# Functions for basic VM setup operations

setup_directories() {
    local vm_base="/var/lib/libvirt"
    local iso_dir="${vm_base}/iso"
    local vm_dir="${vm_base}/images"
    
    mkdir -p "$iso_dir"
    mkdir -p "$vm_dir"
    chown -R libvirt-qemu:libvirt-qemu "$iso_dir"
    chown -R libvirt-qemu:libvirt-qemu "$vm_dir"
    
    echo "$vm_base"
}

setup_network() {
    if ! virsh net-info default >/dev/null 2>&1; then
        echo "Creating default network..." >&2
        virsh net-define /etc/libvirt/qemu/networks/default.xml
        virsh net-autostart default
    fi

    if ! virsh net-info default | grep -q "Active.*yes"; then
        echo "Starting default network..." >&2
        virsh net-start default
    fi
}

download_iso() {
    local iso_dir="$1"
    local version="$2"
    local iso_name="$3"
    
    local iso_url="https://releases.ubuntu.com/${version}/${iso_name}"
    local iso_path="${iso_dir}/${iso_name}"
    
    if [ ! -f "$iso_path" ]; then
        echo "Ubuntu ${version} ISO not found. Downloading from releases.ubuntu.com..." >&2
        wget -O "$iso_path" "$iso_url"
        if [ $? -ne 0 ]; then
            echo "Failed to download ISO" >&2
            return 1
        fi
        chown libvirt-qemu:libvirt-qemu "$iso_path"
        echo "Download completed successfully" >&2
    fi
    
    echo "$iso_path"
}

create_disk() {
    local vm_dir="$1"
    local vm_type="$2"
    local version="$3"
    
    # Generate a unique timestamp
    local timestamp=$(date +%Y%m%d_%H%M%S)
    local vm_base_name="ubuntu-${vm_type}-${version}"
    local vm_unique_name="${vm_base_name}-${timestamp}"
    local vm_img_path="${vm_dir}/${vm_unique_name}.qcow2"
    
    echo "Creating new VM disk image with unique name: ${vm_unique_name}" >&2
    qemu-img create -f qcow2 "$vm_img_path" 20G >&2
    chown libvirt-qemu:libvirt-qemu "$vm_img_path"
    
    # Return both the image path and the unique name
    echo "${vm_img_path}|${vm_unique_name}"
}
