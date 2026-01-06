module "plex_host" {
  source = "../../modules/compute/pve-cloudinit-vm"

  vm_name                         = var.plex_host.name_prefix
  cpu_cores                       = var.plex_host.cpu_cores
  memory_mb                       = var.plex_host.memory_mb
  ci_user_data                    = "vendor=local:snippets/setup-plex-host.yaml"
  cloudinit-example_root-password = var.cloudinit-example_root-password
  os_disk_size                    = var.plex_host.os_disk_size
  network_bridge                  = var.plex_host.network_bridge
}
