data "proxmox_virtual_environment_vms" "noble_template" {
  provider  = pve
  node_name = var.pve.host

  filter {
    name   = "name"
    values = ["noble-template"]
  }
}
