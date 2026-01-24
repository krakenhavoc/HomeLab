clone_vm_id = 9000
vm_disk_datastore_id = "hdd_556g_thin"
vm_cloudinit_datastore_id = "ssd_1641G_thin"
plex_host = {
  env            = "dev"
  name_prefix    = "plex-hibiscus"
  description    = "Plex Media Server"
  tags           = ["plex", "dev"]
  bios           = "ovmf"
  cpu_cores      = 2
  memory_mb      = 4096
  os_disk_size   = 30
  disk_interface = "virtio0"
  network_bridge = "vmbr0"
  vlan_id        = 201
}
nfs_server_ip = "192.168.201.9"
nfs_server_path = "/export/nfs/media"
