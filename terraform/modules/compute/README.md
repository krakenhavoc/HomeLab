# Compute Resources (Terraform)

This directory contains Terraform configurations for compute resources including virtual machines and containers.

## Overview

Manages compute infrastructure:
- Proxmox virtual machines
- VM templates
- Resource pools
- Container hosts
- Compute clusters

## Files

- `main.tf`: Main compute configuration
- `variables.tf`: Input variables
- `outputs.tf`: Output values
- `vms.tf`: Virtual machine definitions
- `templates.tf`: VM template configurations
- `versions.tf`: Provider version constraints

## Proxmox Provider Configuration

### Provider Setup (versions.tf)

```hcl
terraform {
  required_version = ">= 1.0"

  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 2.9"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = var.proxmox_tls_insecure
  pm_parallel         = 2
  pm_timeout          = 600
  pm_log_enable       = true
  pm_log_file         = "terraform-plugin-proxmox.log"
}
```

## Virtual Machine Configuration

### Basic VM (vms.tf)

```hcl
resource "proxmox_vm_qemu" "web_server" {
  count       = var.web_server_count
  name        = "web-server-${count.index + 1}"
  target_node = var.proxmox_node
  clone       = "ubuntu-2204-template"

  # VM Settings
  agent       = 1
  cores       = 2
  sockets     = 1
  cpu         = "host"
  memory      = 4096
  scsihw      = "virtio-scsi-pci"
  bootdisk    = "scsi0"

  # Network
  network {
    bridge = "vmbr0"
    model  = "virtio"
    tag    = 10  # Server VLAN
  }

  # Disk
  disk {
    size    = "50G"
    type    = "scsi"
    storage = "local-zfs"
    iothread = 1
  }

  # Cloud-init
  os_type    = "cloud-init"
  ipconfig0  = "ip=192.168.10.${10 + count.index}/24,gw=192.168.10.1"
  nameserver = "192.168.1.2"

  # SSH Keys
  sshkeys = var.ssh_public_key

  lifecycle {
    ignore_changes = [
      network,
    ]
  }
}
```

### Advanced VM Configuration

```hcl
resource "proxmox_vm_qemu" "database_server" {
  name        = "db-server-01"
  target_node = "pve-node-01"
  clone       = "ubuntu-2204-template"

  # High-performance settings
  agent       = 1
  cores       = 4
  sockets     = 1
  cpu         = "host"
  memory      = 16384
  balloon     = 0  # Disable ballooning for databases

  # Multiple disks
  disk {
    size     = "100G"
    type     = "scsi"
    storage  = "nvme-pool"
    iothread = 1
    cache    = "writethrough"
  }

  disk {
    size     = "500G"
    type     = "scsi"
    storage  = "ssd-pool"
    iothread = 1
    cache    = "writethrough"
  }

  # Network with multiple interfaces
  network {
    bridge   = "vmbr0"
    model    = "virtio"
    tag      = 10
    firewall = true
  }

  network {
    bridge   = "vmbr1"
    model    = "virtio"
    tag      = 100  # Storage network
    firewall = false
  }

  # Cloud-init configuration
  os_type    = "cloud-init"
  ipconfig0  = "ip=192.168.10.20/24,gw=192.168.10.1"
  ipconfig1  = "ip=10.0.100.20/24"
  nameserver = "192.168.1.2,1.1.1.1"

  sshkeys = var.ssh_public_key

  # Custom cloud-init
  cicustom = "user=local:snippets/db-cloud-init.yml"
}
```

## VM Templates

### Creating Templates (templates.tf)

```hcl
resource "proxmox_vm_qemu" "ubuntu_template" {
  name        = "ubuntu-2204-template"
  target_node = var.proxmox_node

  # Template settings
  template    = true

  # Download cloud image
  iso         = "local:iso/ubuntu-22.04-server-cloudimg-amd64.img"

  cores       = 2
  memory      = 2048

  disk {
    size    = "32G"
    type    = "scsi"
    storage = "local-zfs"
  }

  network {
    bridge = "vmbr0"
    model  = "virtio"
  }

  os_type = "cloud-init"

  lifecycle {
    prevent_destroy = true
  }
}
```

## Variables Configuration

### variables.tf

```hcl
variable "proxmox_api_url" {
  description = "Proxmox API URL"
  type        = string
  default     = "https://proxmox.homelab.local:8006/api2/json"
}

variable "proxmox_api_token_id" {
  description = "Proxmox API Token ID"
  type        = string
  sensitive   = true
}

variable "proxmox_api_token_secret" {
  description = "Proxmox API Token Secret"
  type        = string
  sensitive   = true
}

variable "proxmox_tls_insecure" {
  description = "Skip TLS verification"
  type        = bool
  default     = true
}

variable "proxmox_node" {
  description = "Proxmox node name"
  type        = string
  default     = "pve-node-01"
}

variable "ssh_public_key" {
  description = "SSH public key for VM access"
  type        = string
}

variable "web_server_count" {
  description = "Number of web servers"
  type        = number
  default     = 3

  validation {
    condition     = var.web_server_count > 0 && var.web_server_count <= 10
    error_message = "Web server count must be between 1 and 10."
  }
}

variable "vm_defaults" {
  description = "Default VM settings"
  type = object({
    cores   = number
    memory  = number
    storage = string
  })

  default = {
    cores   = 2
    memory  = 4096
    storage = "local-zfs"
  }
}
```

## Outputs

### outputs.tf

```hcl
output "vm_ip_addresses" {
  description = "IP addresses of created VMs"
  value = {
    for vm in proxmox_vm_qemu.web_server :
    vm.name => vm.default_ipv4_address
  }
}

output "vm_ids" {
  description = "VM IDs in Proxmox"
  value = {
    for vm in proxmox_vm_qemu.web_server :
    vm.name => vm.vmid
  }
}

output "ssh_connection_strings" {
  description = "SSH connection strings for VMs"
  value = {
    for vm in proxmox_vm_qemu.web_server :
    vm.name => "ssh ubuntu@${vm.default_ipv4_address}"
  }
}
```

## Usage

### Environment Variables

```bash
export TF_VAR_proxmox_api_token_id="terraform@pam!terraform"
export TF_VAR_proxmox_api_token_secret="your-secret-here"
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
```

### Terraform Commands

```bash
# Initialize
terraform init

# Create execution plan
terraform plan -out=compute.tfplan

# Apply changes
terraform apply compute.tfplan

# Destroy resources
terraform destroy
```

### Creating Specific VMs

```bash
# Create only web servers
terraform apply -target=proxmox_vm_qemu.web_server

# Create single VM instance
terraform apply -target=proxmox_vm_qemu.web_server[0]
```

## Modules

### Reusable VM Module

Create `modules/vm/main.tf`:

```hcl
variable "vm_name" {}
variable "cores" { default = 2 }
variable "memory" { default = 4096 }
variable "disk_size" { default = "50G" }
variable "vlan_tag" {}

resource "proxmox_vm_qemu" "vm" {
  name        = var.vm_name
  target_node = var.proxmox_node
  clone       = "ubuntu-2204-template"

  cores       = var.cores
  memory      = var.memory

  disk {
    size    = var.disk_size
    storage = "local-zfs"
  }

  network {
    bridge = "vmbr0"
    tag    = var.vlan_tag
  }
}

output "ip_address" {
  value = proxmox_vm_qemu.vm.default_ipv4_address
}
```

Use the module:

```hcl
module "app_servers" {
  source = "./modules/vm"

  count     = 3
  vm_name   = "app-server-${count.index + 1}"
  cores     = 4
  memory    = 8192
  disk_size = "100G"
  vlan_tag  = 10
}
```

## Best Practices

1. **Resource Naming**
   - Use consistent naming conventions
   - Include environment in name
   - Use descriptive names

2. **Resource Organization**
   - Group similar VMs
   - Use modules for reusability
   - Separate by function

3. **State Management**
   - Use remote state
   - Enable state locking
   - Regular state backups

4. **Documentation**
   - Comment complex configurations
   - Document dependencies
   - Maintain README files

## Integration with Ansible

After VM creation, configure with Ansible:

```bash
# Export inventory
terraform output -json > /tmp/terraform-output.json

# Run Ansible playbook
cd ../../ansible
ansible-playbook -i inventory/dynamic_terraform.py playbooks/configure-vms.yml
```

## Troubleshooting

### VM Creation Fails

```bash
# Check Proxmox logs
ssh root@proxmox "tail -f /var/log/pve/tasks/active"

# Verify template exists
ssh root@proxmox "qm list"

# Check storage availability
ssh root@proxmox "pvesm status"
```

### Network Issues

```bash
# Verify VLAN configuration
# Check bridge settings
# Test connectivity from host
```

## Security

- Use API tokens (not passwords)
- Restrict token permissions
- Enable firewall on VMs
- Use SSH keys only
- Regular security updates

## Monitoring

After deployment, add VMs to monitoring:
- Prometheus node exporters
- Grafana dashboards
- Alert rules
- Log aggregation

## Future Enhancements

- Implement VM autoscaling
- Add GPU passthrough configurations
- Integrate with Kubernetes
- Automated backup integration
- Advanced networking (SR-IOV)
