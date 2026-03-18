resource "proxmox_virtual_environment_file" "openclaw_cloudinit" {
  provider     = pve
  content_type = "snippets"
  datastore_id = "snippets"
  node_name    = var.pve.host

  source_raw {
    data = templatefile("${path.module}/templates/setup-openclaw.yaml.tftpl", {
      openclaw_hostname = var.openclaw.name_prefix
      admin_username    = var.openclaw.admin_username
    })
    file_name = "setup-${var.openclaw.name_prefix}.yaml"
  }
}

module "openclaw" {
  source = "git::https://github.com/krakenhavoc/HomeLab.git//terraform/modules/compute/pm-cloudinit-vm?ref=v0.2.0"

  vm_name                        = var.openclaw.name_prefix
  vm_node_name                   = var.pve.host
  vm_description                 = var.openclaw.description
  vm_tags                        = var.openclaw.tags
  vm_bios                        = var.openclaw.bios
  clone_vm_id                    = data.proxmox_virtual_environment_vms.noble_template.vms[0].vm_id
  vm_cpu_cores                   = var.openclaw.cpu_cores
  vm_memory_mb                   = var.openclaw.memory_mb
  vm_disk_datastore_id           = var.vm_disk_datastore_id
  vm_disk_interface              = var.openclaw.disk_interface
  vm_disk_size                   = var.openclaw.os_disk_size
  vm_cloudinit_datastore_id      = var.vm_cloudinit_datastore_id
  vm_cloudinit_user_data_file_id = proxmox_virtual_environment_file.openclaw_cloudinit.id
  vm_network_bridge              = var.openclaw.network_bridge
  vm_vlan_id                     = var.openclaw.vlan_id
}

resource "proxmox_virtual_environment_file" "pwnbox_cloudinit" {
  provider     = pve
  content_type = "snippets"
  datastore_id = "snippets"
  node_name    = var.pve.host

  source_raw {
    data = templatefile("${path.module}/templates/setup-pwnbox.yaml.tftpl", {
      pwnbox_admin_username = var.pwnbox.admin_username
      pwnbox_hostname       = var.pwnbox.name_prefix
    })
    file_name = "setup-${var.pwnbox.name_prefix}.yaml"
  }
}

module "pwnbox" {
  source = "git::https://github.com/krakenhavoc/HomeLab.git//terraform/modules/compute/pm-cloudinit-vm?ref=v0.2.0"

  vm_name                        = var.pwnbox.name_prefix
  vm_node_name                   = var.pve.host
  vm_description                 = var.pwnbox.description
  vm_tags                        = var.pwnbox.tags
  vm_bios                        = var.pwnbox.bios
  clone_vm_id                    = data.proxmox_virtual_environment_vms.noble_template.vms[0].vm_id
  vm_cpu_cores                   = var.pwnbox.cpu_cores
  vm_memory_mb                   = var.pwnbox.memory_mb
  vm_disk_datastore_id           = var.vm_disk_datastore_id
  vm_disk_interface              = var.pwnbox.disk_interface
  vm_disk_size                   = var.pwnbox.os_disk_size
  vm_cloudinit_datastore_id      = var.vm_cloudinit_datastore_id
  vm_cloudinit_user_data_file_id = proxmox_virtual_environment_file.pwnbox_cloudinit.id
  vm_network_bridge              = var.pwnbox.network_bridge
  vm_vlan_id                     = var.pwnbox.vlan_id
}

# -----------------------------------------------------------------------------
# Windows 11 VM
# -----------------------------------------------------------------------------
# Uses a raw resource instead of the cloud-init module since Windows requires
# ISO-based installation with UEFI, TPM 2.0, and VirtIO driver loading.
# Post-apply steps:
#   1. Attach virtio-win.iso as a second CD-ROM via Proxmox UI (Hardware > Add > CD/DVD)
#   2. Boot the VM and install Windows via the Proxmox console
#   3. During disk selection, load driver: vioscsi\w11\amd64 from the VirtIO CD
#   4. After install, run virtio-win-gt-x64.msi from the VirtIO CD for all drivers + QEMU Guest Agent

resource "proxmox_virtual_environment_vm" "windows11" {
  provider = pve

  name        = var.windows11.name_prefix
  node_name   = var.pve.host
  description = var.windows11.description
  tags        = sort(concat(["terraform"], var.windows11.tags))
  on_boot     = false
  bios        = "ovmf"
  machine     = "q35"

  operating_system {
    type = "win11"
  }

  cpu {
    type    = "host"
    cores   = var.windows11.cpu_cores
    sockets = 1
    flags   = ["+vmx"]
  }

  memory {
    dedicated = var.windows11.memory_mb
    floating  = 0
  }

  tpm_state {
    version      = "v2.0"
    datastore_id = var.vm_disk_datastore_id
  }

  efi_disk {
    datastore_id      = var.vm_disk_datastore_id
    file_format       = "raw"
    type              = "4m"
    pre_enrolled_keys = true
  }

  # OS disk — VirtIO SCSI for best performance
  disk {
    interface    = "scsi0"
    datastore_id = var.vm_disk_datastore_id
    size         = var.windows11.os_disk_size
    file_format  = "raw"
    cache        = "writeback"
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  scsi_hardware = "virtio-scsi-single"

  # Windows 11 installation ISO
  cdrom {
    file_id   = "local:iso/win11-latest.iso"
    interface = "ide0"
  }

  agent {
    enabled = true
    type    = "virtio"
    trim    = true
  }

  network_device {
    model   = "virtio"
    bridge  = var.windows11.network_bridge
    vlan_id = var.windows11.vlan_id
  }

  vga {
    type   = "virtio"
    memory = 64
  }

  stop_on_destroy = true
}
