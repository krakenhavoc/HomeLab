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
  source = "git::https://github.com/krakenhavoc/HomeLab.git//terraform/modules/compute/pm-cloudinit-vm?ref=feature/pm-vm-vlan"

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
