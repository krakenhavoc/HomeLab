vm_disk_datastore_id      = "hdd_556g_thin"
vm_cloudinit_datastore_id = "hdd_556g_thin"

# pfe is the lab gateway. Caddy terminates TLS for every internal name and
# proxies to the service behind it, with a Homepage portal at lab.labxp.io.
# Design: docs/gateway.md. Runtime config: gateway/.
pfe_host = {
  # Legacy host name; change only at a planned rebuild.
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

  # Confirmed outside the VLAN 201 DHCP pool. Both Pi-holes point every
  # internal gateway name at this address, so it has to be declared rather
  # than leased -- a rebuild that drew a different lease would break every
  # name in the lab at once.
  ipv4_address = "192.168.201.14/24"
  ipv4_gateway = "192.168.201.1"

  # Both Pi-holes, not one: a static host has no lease to fall back on, so a
  # single resolver means every lookup on the gateway stops while that
  # Pi-hole reboots.
  #
  # They are on VLAN 10 and this host is on VLAN 201, so reaching them is an
  # inter-VLAN flow needing a firewall rule for :53, UDP and TCP. Easy to
  # miss because they are the gateway's own resolvers rather than one of the
  # services it proxies -- and missing it presents as a first boot that
  # hangs, not as a DNS error.
  dns_servers = ["192.168.10.11", "192.168.10.12"]
  dns_domain  = "labxp.io"
}
