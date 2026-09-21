vm_disk_datastore_id      = "hdd_556g_thin"
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

  # --- Static addressing: COMMENTED, BLOCKED ON ONE FACT ---------------------
  # This host is becoming the lab gateway (docs/gateway.md); every internal
  # DNS name is about to resolve here, so the address has to stop being a DHCP
  # lease. Address and gateway below are supplied and confirmed. dns_servers
  # is NOT, and the validation in variables.tf refuses ipv4_address without
  # it -- deliberately, because a static address drops the DHCP lease and its
  # resolvers with it, and this host's cloud-init installs Docker over the
  # network. An empty resolv.conf here does not read as a DNS fault; it reads
  # as a first boot that never finishes.
  #
  # Needed to enable: both Pi-hole addresses. Both, not one -- a static host
  # has no lease to fall back on, so a single resolver means every name
  # lookup on the gateway stops while that Pi-hole reboots.
  #
  # Also requires the module ref bump in main.tf; see the block there.
  #
  # ipv4_address = "192.168.201.14/24" # confirmed outside the VLAN 201 pool
  # ipv4_gateway = "192.168.201.1"
  # dns_servers  = ["192.168.X.X", "192.168.X.X"] # both Pi-holes -- UNKNOWN
  # dns_domain   = "labxp.io"
}
