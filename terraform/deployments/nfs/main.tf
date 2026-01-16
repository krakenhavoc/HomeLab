resource "proxmox_virtual_environment_file" "nfs_cloudinit" {
  provider     = pve
  content_type = "snippets"
  datastore_id = "snippets"
  node_name    = var.pve.host

  source_raw {
    data = templatefile("${path.module}/templates/setup-nfs-server.yaml.tftpl", {
      hostname       = "${var.nfs_host.name_prefix}-${var.nfs_host.env}",
      admin_username = "nfs"
    })
    file_name = "setup-nfs-${var.nfs_host.env}.yaml"
  }
}

module "nfs_host" {
  source = "git::https://github.com/krakenhavoc/HomeLab.git//terraform/modules/compute/pm-cloudinit-vm?ref=feature/pm-vm-vlan"

  vm_name                        = "${var.nfs_host.name_prefix}-${var.nfs_host.env}"
  vm_node_name                   = var.pve.host
  vm_description                 = var.nfs_host.description
  vm_tags                        = var.nfs_host.tags
  vm_bios                        = var.nfs_host.bios
  clone_vm_id                    = var.clone_vm_id
  vm_cpu_cores                   = var.nfs_host.cpu_cores
  vm_memory_mb                   = var.nfs_host.memory_mb
  vm_disk_datastore_id           = var.vm_disk_datastore_id
  vm_disk_interface              = var.nfs_host.disk_interface
  vm_disk_size                   = var.nfs_host.os_disk_size
  vm_cloudinit_datastore_id      = var.vm_cloudinit_datastore_id
  vm_cloudinit_user_data_file_id = proxmox_virtual_environment_file.nfs_cloudinit.id
  vm_network_bridge              = var.nfs_host.network_bridge
  vm_vlan_id                     = var.nfs_host.vlan_id
}
