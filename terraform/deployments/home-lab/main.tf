resource "proxmox_vm_qemu" "cloudinit-example" {
  vmid             = 100
  name             = "test-terraform0"
  target_node      = "pve"
  agent            = 1
  memory           = 1024
  boot             = "order=scsi0"        # has to be the same as the OS disk of the template
  clone            = "ubuntu24-cloudinit" # The name of the template
  scsihw           = "virtio-scsi-single"
  vm_state         = "running"
  automatic_reboot = true

  cpu {
    cores = 2
  }
  # Cloud-Init configuration
  cicustom   = "vendor=local:snippets/qemu-guest-agent.yml" # /var/lib/vz/snippets/qemu-guest-agent.yml
  ciupgrade  = true
  nameserver = "1.1.1.1 8.8.8.8"
  ipconfig0  = "ip=dhcp1,ip6=dhcp"
  skip_ipv6  = true
  ciuser     = "root"
  cipassword = "replace-me"
  sshkeys    = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIE/Pjg7YXZ8Yau9heCc4YWxFlzhThnI+IhUx2hLJRxYE Cloud-Init@Terraform"

  # Most cloud-init images require a serial device for their display
  serial {
    id = 0
  }

  disks {
    scsi {
      scsi0 {
        # We have to specify the disk from our template, else Terraform will think it's not supposed to be there
        disk {
          storage = "local-lvm"
          # The size of the disk should be at least as big as the disk in the template. If it's smaller, the disk will be recreated
          size = "2G"
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
