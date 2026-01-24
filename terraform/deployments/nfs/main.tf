resource "proxmox_virtual_environment_container" "nfs" {
  description = var.nfs_server.description

  node_name = var.pve.host

  unprivileged = false

  initialization {
    hostname = "${var.nfs_server.name_prefix}-${var.nfs_server.env}"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      keys = [
        trimspace(var.ssh_public_key)
      ]
    }
  }

  operating_system {
    template_file_id = data.proxmox_virtual_environment_file.ubuntu_2404_lxc_img.id
    type             = "ubuntu"
  }

  features {
    nesting = true
    mount   = ["nfs"]
  }

  disk {
    datastore_id = var.nfs_server.datastore_id
    size         = var.nfs_server.disk_size
  }
  network_interface {
    name    = "veth0"
    bridge  = var.nfs_server.network_bridge
    vlan_id = var.nfs_server.vlan_id
  }

  mount_point {
    volume = local.volume
    path   = local.mount_path
  }

  startup {
    order      = "1"
    up_delay   = "60"
    down_delay = "60"
  }
}
