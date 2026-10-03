resource "proxmox_virtual_environment_file" "wkjp_host_cloudinit" {
  provider     = pve
  content_type = "snippets"
  datastore_id = "snippets"
  node_name    = var.pve.host

  source_raw {
    data = templatefile("${path.module}/templates/setup-wkjp.yaml.tftpl", {
      hostname       = "${var.wkjp_host.name_prefix}-${var.wkjp_host.env}",
      admin_username = "wkjp"
    })
    file_name = "setup-wkjp-${var.wkjp_host.env}.yaml"
  }
}

# WaniKani listening practice (https://wkjp.labxp.io): static app + VOICEVOX.
# pfe terminates TLS and proxies to :80. Runtime config is wkjp/ in this repo,
# reconciled by wkjp-sync. Stateless, so a rebuild loses nothing.
resource "proxmox_virtual_environment_vm" "wkjp" {
  provider = pve

  name        = "${var.wkjp_host.name_prefix}-${var.wkjp_host.env}"
  node_name   = var.pve.host
  description = var.wkjp_host.description
  tags        = sort(concat(["terraform"], var.wkjp_host.tags))
  bios        = var.wkjp_host.bios

  clone {
    vm_id = data.proxmox_virtual_environment_vms.noble_template.vms[0].vm_id
    full  = true
  }

  agent {
    enabled = true
    trim    = true
  }

  cpu {
    cores = var.wkjp_host.cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.wkjp_host.memory_mb
  }

  disk {
    datastore_id = var.vm_disk_datastore_id
    interface    = var.wkjp_host.disk_interface
    iothread     = true
    discard      = "on"
    size         = var.wkjp_host.os_disk_size
  }

  initialization {
    datastore_id = var.vm_cloudinit_datastore_id
    # Address comes from the firewall's static lease for mac_address.
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
    user_data_file_id = proxmox_virtual_environment_file.wkjp_host_cloudinit.id
  }

  network_device {
    bridge      = var.wkjp_host.network_bridge
    vlan_id     = var.wkjp_host.vlan_id
    mac_address = var.wkjp_host.mac_address
  }

  serial_device {}

  vga {
    type = "std"
  }

  operating_system {
    type = "l26"
  }
}
