pve = {
  endpoint = "https://pve.labxp.io:8006"
  host     = "pve"
}
vm_disk_datastore_id      = "ssd_1641G_thin"
vm_cloudinit_datastore_id = "ssd_1641G_thin"
pwnbox = {
  name_prefix    = "pwnbox"
  description    = "CTF Pwnbox - Managed by Terraform"
  tags           = ["ctf"]
  bios           = "ovmf"
  cpu_cores      = 4
  memory_mb      = 8192
  os_disk_size   = 50
  disk_interface = "virtio0"
  network_bridge = "vmbr0"
  vlan_id        = 200
  admin_username = "krkn"
}
