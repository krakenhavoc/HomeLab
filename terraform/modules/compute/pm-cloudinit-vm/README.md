# Proxmox Cloud-init VM Module (pm provider)

Terraform module for creating Proxmox virtual machines with cloud-init support using the modern Proxmox provider.

## Overview

This module creates VMs on Proxmox using the `bpg/proxmox` provider with cloud-init support for automated configuration.

## Usage

```hcl
module "vm" {
  source = "../../modules/compute/pm-cloudinit-vm"
  
  vm_name     = "web-server-01"
  target_node = "pve"
  cpu_cores   = 2
  memory_mb   = 4096
  disk_size   = "50G"
  
  network_bridge = "vmbr0"
  vlan_tag       = 10
  
  ssh_keys = [var.ssh_public_key]
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| vm_name | Name of the VM | string | n/a | yes |
| target_node | Proxmox node name | string | n/a | yes |
| cpu_cores | Number of CPU cores | number | 2 | no |
| memory_mb | Memory in MB | number | 4096 | no |
| disk_size | Disk size (e.g., "50G") | string | "50G" | no |
| network_bridge | Network bridge | string | "vmbr0" | no |
| vlan_tag | VLAN tag | number | null | no |
| ssh_keys | List of SSH public keys | list(string) | [] | no |

## Outputs

| Name | Description |
|------|-------------|
| vm_id | The ID of the created VM |
| vm_ip | The IP address of the VM |
| vm_name | The name of the VM |

## Requirements

- Terraform >= 1.0
- Proxmox provider (bpg/proxmox) >= 0.40
- Proxmox VE 7.x or later
- Cloud-init template available

## Features

- Cloud-init support
- Flexible resource configuration
- Network configuration with VLAN support
- SSH key injection
- Customizable disk and compute resources

See module source code for full configuration options.
