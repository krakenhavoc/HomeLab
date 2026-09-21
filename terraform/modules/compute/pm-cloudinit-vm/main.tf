resource "proxmox_virtual_environment_vm" "this" {
  name        = var.vm_name
  node_name   = var.vm_node_name
  description = var.vm_description
  tags        = var.vm_tags

  bios = var.vm_bios

  clone {
    vm_id = var.clone_vm_id
    full  = true
  }

  agent {
    enabled = var.vm_agent_enabled
    trim    = true
  }

  cpu {
    cores = var.vm_cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.vm_memory_mb
  }

  disk {
    datastore_id = var.vm_disk_datastore_id
    interface    = var.vm_disk_interface
    iothread     = true
    discard      = "on"
    size         = var.vm_disk_size
  }

  initialization {
    datastore_id = var.vm_cloudinit_datastore_id
    ip_config {
      ipv4 {
        # "dhcp" is the literal the provider expects for a lease; anything else
        # is written through to the guest's ipconfig0 line. The fallback lives
        # here rather than in the variable's default so that null/not-null on
        # var.vm_ipv4_address stays the single answer to "is this host
        # statically addressed?" — the gateway validation depends on it.
        address = var.vm_ipv4_address == null ? "dhcp" : var.vm_ipv4_address

        # Terraform treats an ATTRIBUTE set to null exactly as it treats one
        # that was never written, so a VM that leaves vm_ipv4_gateway unset
        # renders the same ipv4 block it rendered before this line existed —
        # no diff for openclaw, pwnbox, redlib or plex. A null BLOCK is a
        # different story; see the dynamic below.
        gateway = var.vm_ipv4_gateway
      }
    }

    # dns is a block, and a block cannot be nulled out of existence: writing
    # `dns {}` unconditionally emits a real, empty block that says "this guest
    # has no resolvers and no search domain", which is emphatically not the
    # same as "leave the guest on whatever DHCP gave it". A dynamic over a
    # one-or-zero element list is the only way to render nothing at all, and
    # rendering nothing is what keeps the existing consumers at zero diff.
    #
    # The condition is OR, not AND: a search domain on top of DHCP-supplied
    # resolvers is a legitimate ask, and so is a resolver list with no domain.
    dynamic "dns" {
      for_each = length(var.vm_dns_servers) > 0 || var.vm_dns_domain != null ? [1] : []

      content {
        # null rather than [], for the same reason as the gateway above: an
        # empty list is a declaration that the guest has no resolvers, which
        # would clobber the DHCP-supplied ones in the domain-only case.
        servers = length(var.vm_dns_servers) > 0 ? var.vm_dns_servers : null
        domain  = var.vm_dns_domain
      }
    }

    user_data_file_id = var.vm_cloudinit_user_data_file_id
  }

  network_device {
    bridge  = var.vm_network_bridge
    vlan_id = var.vm_vlan_id

    # mac_address is optional AND computed in the provider schema, so null
    # hands the choice back to Proxmox on create and keeps whatever is already
    # recorded in state on an existing VM. That is exactly the behaviour this
    # module had before the attribute was written here, which is why adding
    # the line needs no dynamic block and produces no diff for the VMs that
    # leave it unset.
    mac_address = var.vm_mac_address
  }

  serial_device {}

  vga {
    type = "std"
  }

  operating_system {
    type = "l26"
  }
}
