nfs_server = {
  env            = "prd"
  name_prefix    = "nfs"
  description    = "NFS Server"
  tags           = ["nfs", "prd"]
  cpu_cores      = 4
  memory_mb      = 4096
  disk_interface = "virtio0"
  network_bridge = "vmbr0"
  vlan_id        = 10
  ipv4_address   = "192.168.10.9/24"
  ipv4_gateway   = "192.168.10.1"
  datastore_id   = "ssd_1641G_thin"
  disk_size      = 10
}
