nfs_server = {
  env            = "dev"
  name_prefix    = "nfs"
  description    = "NFS Server"
  tags           = ["nfs"]
  cpu_cores      = 4
  memory_mb      = 4096
  disk_interface = "virtio0"
  network_bridge = "vmbr0"
  vlan_id        = 201
  datastore_id   = "local-lvm"
  }
