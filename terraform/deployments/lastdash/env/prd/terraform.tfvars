vm_disk_datastore_id      = "hdd_556g_thin"
vm_cloudinit_datastore_id = "hdd_556g_thin"

# LastDash app host. Served at https://lastdash.labxp.io through the gateway.
# Runtime config: lastdash/. Design notes: lastdash/README.md.
lastdash_host = {
  # Legacy host name; change only at a planned rebuild.
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

  # DHCP with a static lease on the firewall keyed on this MAC (Proxmox OUI;
  # BC:24:11:00:02:40 is openclaw-2's). The leased address must match the
  # upstream in gateway/caddy/Caddyfile.
  mac_address = "BC:24:11:00:02:50"
}
