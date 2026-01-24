resource "proxmox_virtual_environment_container" "nfs" {
  description = "Managed by Terraform"

  node_name = var.pve.host

  unprivileged = true

  initialization {
    hostname = "${var.nfs_server.name_prefix}-${var.nfs_server.env}"

    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }

    user_account {
      # keys = [
      #   trimspace(tls_private_key.ubuntu_container_key.public_key_openssh)
      # ]
      # password = random_password.ubuntu_container_password.result
    }
  }

  disk {
    datastore_id = var.nfs_server.datastore_id
    size         = 4
  }

  operating_system {
    template_file_id = data.proxmox_virtual_environment_file.ubuntu_2404_lxc_img.id
    type             = "ubuntu"
  }

  mount_point {
    volume = var.nfs_server.mount_volume
    path   = var.nfs_server.mount_path
  }


  startup {
    order      = "3"
    up_delay   = "60"
    down_delay = "60"
  }
}
