resource "proxmox_vm_qemu" "this" {
  name             = var.vm_name
  target_node      = var.pve_node
  agent            = var.enable_qemu_guest_agent
  memory           = var.memory_bytes
  boot             = "order=virtio0" # has to be the same as the OS disk of the template
  clone            = var.clone_name
  scsihw           = "virtio-scsi-single"
  vm_state         = var.vm_state
  automatic_reboot = true

  cpu {
    cores = var.cpu_cores
  }
  # Cloud-Init configuration
  cicustom   = "vendor=local:snippets/ubuntu.yml"
  ciupgrade  = true
  nameserver = var.dns_nameservers
  ipconfig0  = "ip=dhcp"
  skip_ipv6  = true
  ciuser     = var.username
  cipassword = var.cloudinit-example_root-password

  # Most cloud-init images require a serial device for their display
  serial {
    id = 0
  }

  disks {
    virtio {
      virtio0 {
        # We have to specify the disk from our template, else Terraform will think it's not supposed to be there
        disk {
          storage = "local-lvm"
          # The size of the disk should be at least as big as the disk in the template. If it's smaller, the disk will be recreated
          size = var.os_disk_size
        }
      }
    }
    ide {
      # Some images require a cloud-init disk on the IDE controller, others on the SCSI or SATA controller
      ide1 {
        cloudinit {
          storage = "local-lvm"
        }
      }
    }
  }

  network {
    id     = 0
    bridge = "vmbr0"
    model  = "virtio"
  }
}
