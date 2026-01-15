resource "proxmox_virtual_environment_file" "plex_cloudinit" {
  provider     = pve
  content_type = "snippets"
  datastore_id = "snippets"
  node_name    = var.pve.host

  source_raw {
    data = templatefile("${path.module}/templates/setup-plex.yaml.tftpl", {
      hostname       = "${var.plex_host.name_prefix}-${var.plex_host.env}",
      admin_username = "plex"
      docker_compose = indent(6, local.docker_compose)
    })
    file_name = "setup-plex-${var.plex_host.env}.yaml"
  }
}

module "plex_host" {
  source = "git::https://github.com/krakenhavoc/HomeLab.git//terraform/modules/compute/pm-cloudinit-vm?ref=v0.1"

  vm_name                        = "${var.plex_host.name_prefix}-${var.plex_host.env}"
  vm_node_name                   = var.pve.host
  vm_description                 = var.plex_host.description
  vm_tags                        = var.plex_host.tags
  vm_bios                        = var.plex_host.bios
  clone_vm_id                    = var.clone_vm_id
  vm_cpu_cores                   = var.plex_host.cpu_cores
  vm_memory_mb                   = var.plex_host.memory_mb
  vm_disk_datastore_id           = var.vm_disk_datastore_id
  vm_disk_interface              = var.plex_host.disk_interface
  vm_disk_size                   = var.plex_host.os_disk_size
  vm_cloudinit_datastore_id      = var.vm_cloudinit_datastore_id
  vm_cloudinit_user_data_file_id = proxmox_virtual_environment_file.plex_cloudinit.id
  vm_network_bridge              = var.plex_host.network_bridge
}
