# Proxmox Cloud-init VM Module (pve provider)

Terraform module for creating Proxmox virtual machines with cloud-init support using the Telmate Proxmox provider.

## Overview

This module creates VMs on Proxmox using the `Telmate/proxmox` provider with cloud-init support for automated configuration.

## Usage

```hcl
module "vm" {
  source = "../../modules/compute/pve-cloudinit-vm"
  
  vm_name     = "app-server-01"
  target_node = "pve"
  cpu_cores   = 4
  memory_mb   = 8192
  disk_size   = "100G"
  
  network_bridge = "vmbr0"
  vlan_tag       = 10
  
  vm_ip       = "192.168.10.100"
  gateway     = "192.168.10.1"
  nameserver  = "192.168.1.2"
  
  ssh_public_key = var.ssh_public_key
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
| vm_ip | Static IP address | string | "dhcp" | no |
| gateway | Network gateway | string | null | no |
| nameserver | DNS server | string | null | no |
| ssh_public_key | SSH public key | string | "" | no |

## Outputs

| Name | Description |
|------|-------------|
| vm_id | The VM ID in Proxmox |
| vm_ip | The IP address of the VM |
| vm_name | The name of the VM |

## Requirements

- Terraform >= 1.0
- Proxmox provider (Telmate/proxmox) ~> 2.9
- Proxmox VE 7.x or later
- Ubuntu cloud-init template

## Features

- Cloud-init configuration
- Static or DHCP IP addressing
- VLAN support
- SSH key management
- Flexible VM sizing
- Template-based deployment

See module source code for complete configuration options and examples.
