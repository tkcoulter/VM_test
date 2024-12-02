# VM Tests Directory

This directory contains scripts for managing and testing virtual machines (VMs). Located at `/home/ubuntu2/Documents/cloudstack_ubuntu_ansible/vm_tests/`.

## Setup

Before using the scripts, ensure they have execute permissions:
```bash
# Add execute permissions to all script files (from repository root)
sudo chmod +x vm_tests/*.sh vm_tests/functions/*.sh
```

## Available Scripts

### copy_setup_to_vms.sh
Copies the setup_ansible_host directory to all running VMs.

**Configuration:**
At the top of the script, you can set these variables:
```bash
# Default configuration - set these variables to skip prompts
DEFAULT_VM_USERNAME=""    # Set to skip username prompt
DEFAULT_VM_PASSWORD=""    # Set to skip password prompt
DEFAULT_SETUP_PATH="/home/ubuntu2/Documents/cloudstack_ubuntu_ansible/setup_ansible_host"
```

**Usage:**
```bash
# From repository root
sudo ./vm_tests/copy_setup_to_vms.sh
```

### backup_vms.sh
Creates backups of virtual machines.

**Usage:**
```bash
# From repository root
./vm_tests/backup_vms.sh
```

### clear_backups.sh
Removes VM backup files.

**Usage:**
```bash
# From repository root
./vm_tests/clear_backups.sh
```

### clear_vms.sh
Removes virtual machines.

**Usage:**
```bash
# From repository root
./vm_tests/clear_vms.sh
```

### install_desktop.sh
Installs desktop environment on VMs.

**Usage:**
```bash
# From repository root
./vm_tests/install_desktop.sh
```

### install_live.sh
Installs live environment on VMs.

**Usage:**
```bash
# From repository root
./vm_tests/install_live.sh
```

### restore_vm.sh
Restores a VM from backup.

**Usage:**
```bash
# From repository root
./vm_tests/restore_vm.sh
```

### test_vm.sh
Tests VM functionality.

**Usage:**
```bash
# From repository root
./vm_tests/test_vm.sh
```

## Function Files

The `functions/` subdirectory (`/home/ubuntu2/Documents/cloudstack_ubuntu_ansible/vm_tests/functions/`) contains modular bash functions used by the scripts:

- `backup_functions.sh`: Functions for VM backup operations
- `copy_functions.sh`: Functions for copying files to VMs
- `display_functions.sh`: Functions for displaying information
- `network_functions.sh`: Functions for network operations
- `setup_functions.sh`: Functions for VM setup operations

## Common Requirements

- Most scripts require sudo privileges
- VMs must have SSH server installed and running
- For copy operations, the destination user must have a valid home directory
- All commands should be run from the repository root directory: `/home/ubuntu2/Documents/cloudstack_ubuntu_ansible`

## SSH Server Setup

If SSH connection fails, install openssh-server on the VM:

1. For Ubuntu Desktop VMs:
```bash
sudo apt update
sudo apt install -y openssh-server
sudo systemctl enable ssh
sudo systemctl start ssh
sudo sed -i 's/#PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo sed -i 's/PasswordAuthentication.*/PasswordAuthentication yes/' /etc/ssh/sshd_config
sudo systemctl restart ssh
```

2. For Ubuntu Server VMs:
   - SSH server should be installed by default if selected during installation
   - If not, follow the same steps as Desktop VMs

3. Ensure your user has a home directory:
```bash
sudo mkdir -p /home/YOUR_USERNAME
sudo chown YOUR_USERNAME:YOUR_USERNAME /home/YOUR_USERNAME
