vm_disk_datastore_id = "hdd_556g_thin"
vm_cloudinit_datastore_id = "hdd_556g_thin"
pfe_host = {
  env            = "dev"
  name_prefix    = "pfe"
  description    = "Private Frontends Host"
  tags           = ["apps", "dev"]
  bios           = "ovmf"
  cpu_cores      = 2
  memory_mb      = 4096
  os_disk_size   = 30
  disk_interface = "virtio0"
  network_bridge = "vmbr0"
  vlan_id        = 201
}
