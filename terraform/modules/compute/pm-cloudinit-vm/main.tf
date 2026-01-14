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
        address = "dhcp"
      }
    }

    user_data_file_id = var.vm_cloudinit_user_data_file_id
  }

  network_device {
    bridge = var.vm_network_bridge
  }

  serial_device {}

  vga {
    type = "std"
  }

  operating_system {
    type = "l26"
  }
}
