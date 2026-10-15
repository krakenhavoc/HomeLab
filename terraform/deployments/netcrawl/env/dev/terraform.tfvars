vm_disk_datastore_id      = "hdd_556g_thin"
vm_cloudinit_datastore_id = "hdd_556g_thin"

# NetCrawl web build, internal only. Served at https://netcrawl-dev.labxp.io
# through the gateway. Runtime config: netcrawl/. Design: docs/netcrawl-web.md.
#
# "netcrawl" is a working name; the game is being renamed. See
# netcrawl/README.md for everything a rename touches.
netcrawl_host = {
  env         = "dev"
  name_prefix = "netcrawl"
  tags        = ["apps", "dev"]
  # Static files only.
  cpu_cores = 1
  memory_mb = 1024
  # Five releases of ~120 MB plus images and logs.
  os_disk_size = 20

  # Same VLAN as pfe; no inter-VLAN rule needed for the proxied path.
  vlan_id = 201

  # Static lease on the firewall (lastdash :50, wkjp :60). Must match the
  # upstream in gateway/caddy/Caddyfile.
  mac_address = "BC:24:11:00:02:70"
}
