resource "proxmox_virtual_environment_file" "netcrawl_host_cloudinit" {
  provider     = pve
  content_type = "snippets"
  datastore_id = "snippets"
  node_name    = var.pve.host

  source_raw {
    data = templatefile("${path.module}/templates/setup-netcrawl.yaml.tftpl", {
      hostname       = "${var.netcrawl_host.name_prefix}-${var.netcrawl_host.env}",
      admin_username = "netcrawl"
    })
    file_name = "setup-netcrawl-${var.netcrawl_host.env}.yaml"
  }
}

# NetCrawl's Godot web build (https://netcrawl-dev.labxp.io), internal only.
# pfe terminates TLS and proxies to :80. NetCrawl CI pushes releases over a
# write-only deploy key; host config is netcrawl/ in this repo, reconciled by
# netcrawl-sync. Stateless: every release is rebuildable from git, and saves
# live in players' browsers, so a rebuild loses nothing but old releases.
# Design: docs/netcrawl-web.md.
resource "proxmox_virtual_environment_vm" "netcrawl" {
  provider = pve

  name        = "${var.netcrawl_host.name_prefix}-${var.netcrawl_host.env}"
  node_name   = var.pve.host
  description = var.netcrawl_host.description
  tags        = sort(concat(["terraform"], var.netcrawl_host.tags))
  bios        = var.netcrawl_host.bios

  clone {
    vm_id = data.proxmox_virtual_environment_vms.noble_template.vms[0].vm_id
    full  = true
  }

  agent {
    enabled = true
    trim    = true
  }

  cpu {
    cores = var.netcrawl_host.cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.netcrawl_host.memory_mb
  }

  disk {
    datastore_id = var.vm_disk_datastore_id
    interface    = var.netcrawl_host.disk_interface
    iothread     = true
    discard      = "on"
    size         = var.netcrawl_host.os_disk_size
  }

  initialization {
    datastore_id = var.vm_cloudinit_datastore_id
    # Address comes from the firewall's static lease for mac_address.
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
    user_data_file_id = proxmox_virtual_environment_file.netcrawl_host_cloudinit.id
  }

  network_device {
    bridge      = var.netcrawl_host.network_bridge
    vlan_id     = var.netcrawl_host.vlan_id
    mac_address = var.netcrawl_host.mac_address
  }

  serial_device {}

  vga {
    type = "std"
  }

  operating_system {
    type = "l26"
  }
}
