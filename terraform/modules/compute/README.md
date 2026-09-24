# Compute modules

This directory contains two generations of the Proxmox cloud-init VM module.

| Module | Provider | Status |
| --- | --- | --- |
| [`pm-cloudinit-vm`](pm-cloudinit-vm/) | `bpg/proxmox` | Current; use for new Linux VM deployments |
| [`pve-cloudinit-vm`](pve-cloudinit-vm/) | `Telmate/proxmox` | Legacy; retained for compatibility and reference |

## Current module

`pm-cloudinit-vm` creates a full clone from an existing template and configures its compute, disk, agent, cloud-init, and network settings. The caller creates the cloud-init snippet and passes its Proxmox file ID into the module.

### Example

```hcl
module "example" {
  source = "git::https://github.com/krakenhavoc/HomeLab.git//terraform/modules/compute/pm-cloudinit-vm?ref=v0.3.0"

  vm_name                        = "example"
  vm_node_name                   = "pve"
  vm_description                 = "Example service"
  vm_tags                        = ["example"]
  clone_vm_id                    = 9000
  vm_cpu_cores                   = 2
  vm_memory_mb                   = 4096
  vm_disk_datastore_id           = "local-lvm"
  vm_disk_size                   = 30
  vm_cloudinit_datastore_id      = "local-lvm"
  vm_cloudinit_user_data_file_id = proxmox_virtual_environment_file.example.id
  vm_network_bridge              = "vmbr0"
  vm_vlan_id                     = var.service_host.vlan_id
}
```

The released version used by most deployments may lag the module on `main`. Check the selected tag before using inputs that were added recently.

### Network behavior

DHCP is the default. Static network inputs are optional:

```hcl
  vm_ipv4_address = "192.0.2.20/24"
  vm_ipv4_gateway = "192.0.2.1"
  vm_dns_servers  = ["192.0.2.53", "198.51.100.53"]
  vm_dns_domain   = "example.internal"
  vm_mac_address  = "02:00:00:00:00:01"
```

These examples use address ranges reserved for documentation and do not describe the lab network.

The address must include a prefix. The gateway must not. Leaving every optional value unset renders the same DHCP configuration as the earlier module behavior: no gateway attribute, no DNS block, and no pinned MAC.

Static cloud-init networking is consumed at first boot. Changing these inputs on an established VM may rewrite its cloud-init drive and restart the guest without reconfiguring the live OS as expected. Prefer choosing the address before creation or scheduling a deliberate rebuild.

### Lifecycle warning

The module cannot let a caller inject a Terraform `lifecycle` block. A long-lived guest that must ignore `initialization` changes may need a raw resource instead, with the duplicated attributes and the reason documented. `cmd-and-ctrl`, `lastdash`, and `gh-runner` use this pattern; it should not become the default.

### Test the module

```bash
cd terraform/modules/compute/pm-cloudinit-vm
terraform init -backend=false
terraform validate
terraform test
```

The test suite uses a mocked provider and covers defaults, VLAN behavior, BIOS and agent options, disk interfaces, and network validation.

## Legacy module

`pve-cloudinit-vm` uses the Telmate provider and an older input model. It includes guest credentials and cloud-init path conventions that do not match the current BPG-provider deployments. Do not migrate an existing consumer casually: provider and resource-type changes require an explicit state migration and a no-destroy plan.

## Releasing changes

Deployments reference modules by Git tag, so release in this order:

1. Merge and test the backwards-compatible module change.
2. Tag the commit.
3. Update consumers to that tag in a separate pull request.
4. Inspect every consumer plan for initialization, disk, network, and replacement changes.

Never reuse or move an existing tag.
