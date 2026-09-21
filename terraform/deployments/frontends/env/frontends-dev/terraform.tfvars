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

  # --- Static addressing: VALUES COMPLETE, AWAITING MODULE v0.3.0 ------------
  # This host is becoming the lab gateway (docs/gateway.md); every internal
  # DNS name is about to resolve here, so the address has to stop being a DHCP
  # lease. All four values below are supplied and confirmed. They stay
  # commented for exactly one reason: the module ref in main.tf is still
  # v0.2.0, which does not declare these inputs.
  #
  # To enable, in this order:
  #   1. Merge PR #65 (feat/pm-cloudinit-static-addressing). Static addressing
  #      is NOT on main -- main is at 629a999 and its pm-cloudinit-vm has no
  #      vm_ipv4_address at all.
  #   2. Tag v0.3.0 on main.
  #   3. Bump the ref in main.tf and uncomment the pass-through there.
  #   4. Uncomment the four lines below.
  #
  # Both Pi-holes, not one: a static host has no DHCP lease to fall back on,
  # so a single resolver means every name lookup on the gateway stops while
  # that Pi-hole reboots. They are on VLAN 10 and this host is on VLAN 201, so
  # this also needs an inter-VLAN firewall rule for :53 -- see docs/gateway.md.
  #
  # ipv4_address = "192.168.201.14/24" # confirmed outside the VLAN 201 pool
  # ipv4_gateway = "192.168.201.1"
  # dns_servers  = ["192.168.10.11", "192.168.10.12"] # both Pi-holes
  # dns_domain   = "labxp.io"
}
