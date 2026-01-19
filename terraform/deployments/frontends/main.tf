resource "proxmox_virtual_environment_file" "pfe_host_cloudinit" {
  provider     = pve
  content_type = "snippets"
  datastore_id = "snippets"
  node_name    = var.pve.host

  source_raw {
    data = templatefile("${path.module}/templates/setup-pfe.yaml.tftpl", {
      hostname       = "${var.pfe_host.name_prefix}-${var.pfe_host.env}",
      admin_username = "pfe"
      docker_compose = indent(6, local.docker_compose)
    })
    file_name = "setup-pfe-${var.pfe_host.env}.yaml"
  }
}

module "pfe_host" {
  source = "git::https://github.com/krakenhavoc/HomeLab.git//terraform/modules/compute/pm-cloudinit-vm?ref=v0.2.0"

  vm_name                        = "${var.pfe_host.name_prefix}-${var.pfe_host.env}"
  vm_node_name                   = var.pve.host
  vm_description                 = var.pfe_host.description
  vm_tags                        = var.pfe_host.tags
  vm_bios                        = var.pfe_host.bios
  clone_vm_id                    = data.proxmox_virtual_environment_vms.noble_template.vms[0].vm_id
  vm_cpu_cores                   = var.pfe_host.cpu_cores
  vm_memory_mb                   = var.pfe_host.memory_mb
  vm_disk_datastore_id           = var.vm_disk_datastore_id
  vm_disk_interface              = var.pfe_host.disk_interface
  vm_disk_size                   = var.pfe_host.os_disk_size
  vm_cloudinit_datastore_id      = var.vm_cloudinit_datastore_id
  vm_cloudinit_user_data_file_id = proxmox_virtual_environment_file.pfe_host_cloudinit.id
  vm_network_bridge              = var.pfe_host.network_bridge
  vm_vlan_id                     = var.pfe_host.vlan_id
}
