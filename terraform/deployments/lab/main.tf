resource "proxmox_virtual_environment_file" "pwnbox_cloudinit" {
  #Temporary provider block until state is updated to use proxmox provider
  provider     = proxmox
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

resource "proxmox_virtual_environment_vm" "win11_vm" {
  #Temporary provider block until state is updated to use proxmox provider
  provider  = proxmox
  name      = var.win11.name_prefix
  node_name = var.pve.host

  bios = "ovmf"

  cpu {
    cores = var.win11.cpu_cores
    type  = "host"
  }

  memory {
    dedicated = var.win11.memory_mb
  }

  agent {
    enabled = false
  }

  network_device {
    bridge  = var.win11.network_bridge
    vlan_id = var.win11.vlan_id
  }

  disk {
    datastore_id = var.win11.disk_datastore_id
    file_id      = data.proxmox_virtual_environment_file.win11_iso.id
    interface    = var.win11.disk_interface
    size         = var.win11.os_disk_size
  }

  operating_system {
    type = "win11"
  }

  # Windows 11 requires TPM and EFI
  tpm_state {
    version      = "v2.0"
    datastore_id = var.win11.disk_datastore_id
  }

  efi_disk {
    datastore_id      = var.win11.disk_datastore_id
    file_format       = "raw"
    type              = "4m"
    pre_enrolled_keys = true
  }

  cdrom {
    file_id   = data.proxmox_virtual_environment_file.win11_iso.id
    interface = "ide2"
  }
}
