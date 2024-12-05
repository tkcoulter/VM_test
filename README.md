# VM Tests Directory

This directory contains scripts for managing and testing virtual machines (VMs).

## Setup

Before using the scripts, ensure they have execute permissions:
```bash
sudo chmod +x *.sh functions/*.sh
```

## Available Scripts

### test_vm.sh
Creates a new VM with a unique timestamp-based name.

**Usage:**
```bash
sudo ./test_vm.sh [desktop|live] [version]

# Examples:
sudo ./test_vm.sh desktop 24.04
sudo ./test_vm.sh live 24.04
```

Each VM is created with a unique name in the format: `ubuntu-[type]-[version]-[YYYYMMDD_HHMMSS]`
This allows running multiple VMs of the same type and version simultaneously.

### copy_setup_to_vms.sh
Copies setup files to all running VMs.

**Configuration:**
At the top of the script, you can set these variables:
```bash
# Default configuration - set these variables to skip prompts
DEFAULT_VM_USERNAME=""    # Set to skip username prompt
DEFAULT_VM_PASSWORD=""    # Set to skip password prompt
DEFAULT_SETUP_PATH="/path/to/setup/files"
```

**Usage:**
```bash
sudo ./copy_setup_to_vms.sh
```

### backup_vms.sh
Creates backups of all running virtual machines. Each backup preserves the VM's unique name.

**Usage:**
```bash
sudo ./backup_vms.sh
```

### restore_vm.sh
Restores a VM from backup. The restored VM will have a new unique timestamp-based name to prevent conflicts.

**Usage:**
```bash
sudo ./restore_vm.sh [desktop|live]

# Examples:
sudo ./restore_vm.sh desktop
sudo ./restore_vm.sh live
```

### clear_vms.sh
Removes all VMs (both old format and new timestamp-based names).

**Usage:**
```bash
sudo ./clear_vms.sh
```

### clear_backups.sh
Removes all VM backup files.

**Usage:**
```bash
sudo ./clear_backups.sh
```

### install_desktop.sh and install_live.sh
Internal scripts used by test_vm.sh to create desktop and live VMs respectively.

## Function Files

The `functions/` subdirectory contains modular bash functions used by the scripts:

- `backup_functions.sh`: Functions for VM backup operations
- `copy_functions.sh`: Functions for copying files to VMs
- `display_functions.sh`: Functions for displaying information
- `network_functions.sh`: Functions for network operations
- `setup_functions.sh`: Functions for VM setup operations

## Common Requirements

- Most scripts require sudo privileges
- VMs must have SSH server installed and running
- For copy operations, the destination user must have a valid home directory

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
```

## VM Naming Convention

VMs are created with unique timestamp-based names to allow running multiple instances:

- Format: `ubuntu-[type]-[version]-[YYYYMMDD_HHMMSS]`
- Example: `ubuntu-desktop-24.04-20240315_143022`

This naming scheme allows:
- Running multiple VMs of the same type and version
- Easy identification of when each VM was created
- Conflict-free VM restoration from backups
