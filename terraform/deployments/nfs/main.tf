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
        trimspace(var.ssh_public_key),
        "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIIJSS8CuvRGR2JHN4HShwOcMu0UP7R6lY/K94kk78JMM"
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

  provisioner "remote-exec" {
    inline = [
      # 1. Update and install NFS server
      "apt-get update",
      "apt-get install -y nfs-kernel-server",

      # 2. Ensure the export directory exists inside the LXC
      "mkdir -p ${local.mount_path}",

      # 3. Configure the export
      # We use fsid=1 to prevent 'stale file handle' errors on bind mounts
      # We use no_root_squash because 'root' is already mapped to 100000 on the host
      "echo '${local.mount_path} *(rw,sync,no_subtree_check,no_root_squash,fsid=1)' > /etc/exports",

      # 4. Restart and enable services
      "systemctl restart nfs-kernel-server",
      "systemctl enable nfs-kernel-server"
    ]

    connection {
      type = "ssh"
      user = "root"
      # This targets the DHCP address assigned during initialization
      host        = self.initialization[0].ip_config[0].ipv4[0].address == "dhcp" ? self.network_interface[0].name : self.initialization[0].ip_config[0].ipv4[0].address
      private_key = file("~/.ssh/id_proxmox")
    }
  }
}
