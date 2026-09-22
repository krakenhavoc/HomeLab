vm_disk_datastore_id      = "hdd_556g_thin"
vm_cloudinit_datastore_id = "hdd_556g_thin"

# LastDash app host. Served at https://lastdash.labxp.io through the gateway.
# Runtime config: lastdash/. Design notes: lastdash/README.md.
lastdash_host = {
  env         = "prod"
  name_prefix = "lastdash"
  description = "LastDash app host (web, api, postgres, redis)"
  tags        = ["apps", "prod"]
  cpu_cores   = 2
  memory_mb   = 4096
  # Room for images, Postgres and Redis on the one disk.
  os_disk_size = 40

  # VLAN 201, same as pfe, so the gateway reaches :3000/:3001 without an
  # inter-VLAN firewall rule.
  vlan_id = 201

  # TODO(before merge): a free address OUTSIDE the VLAN 201 DHCP pool.
  # Taken today: .1 (gateway), .9 (nfs), .14 (pfe). Must match the upstream
  # in gateway/caddy/Caddyfile.
  ipv4_address = "192.168.201.REPLACE_ME/24"
  ipv4_gateway = "192.168.201.1"

  # Both Pi-holes (VLAN 10): needs the same :53 UDP/TCP rule pfe has.
  dns_servers = ["192.168.10.11", "192.168.10.12"]
  dns_domain  = "labxp.io"
}
