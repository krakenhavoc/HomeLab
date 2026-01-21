data "proxmox_virtual_environment_vms" "noble_template" {
  node_name = var.pve.host

  filter {
    name   = "name"
    values = ["noble-template"]
  }
}

data "proxmox_virtual_environment_file" "win11_iso" {
  node_name    = "pve"
  datastore_id = "local"
  content_type = "iso"
  file_name    = "win11-latest.iso"
}
