clone_vm_id = 9000
vm_disk_datastore_id = "ssd_1641G_thin"
vm_cloudinit_datastore_id = "ssd_1641G_thin"
plex_host = {
  env            = "prd"
  name_prefix    = "plex-hibiscus"
  description    = "Plex Media Server"
  tags           = ["plex", "prd"]
  bios           = "ovmf"
  cpu_cores      = 4
  memory_mb      = 8192
  os_disk_size   = 30
  disk_interface = "virtio0"
  network_bridge = "vmbr0"
  vlan_id        = 10
}
nfs_server_ip = "192.168.10.9"
nfs_server_path = "/export/nfs/media"
