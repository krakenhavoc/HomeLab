vm_disk_datastore_id      = "hdd_556g_thin"
vm_cloudinit_datastore_id = "hdd_556g_thin"

# WaniKani listening practice. Served at https://wkjp.labxp.io through the
# gateway. Runtime config: wkjp/.
wkjp_host = {
  env         = "prd"
  name_prefix = "wkjp"
  tags        = ["apps", "prd"]
  # VOICEVOX (CPU) wants ~1.5 GB resident; synthesis is CPU-bound.
  cpu_cores = 2
  memory_mb = 4096
  # VOICEVOX image is ~3 GB.
  os_disk_size = 30

  # Same VLAN as pfe; no inter-VLAN rule needed.
  vlan_id = 201

  # Static lease on the firewall (lastdash is :50). Must match the upstream
  # in gateway/caddy/Caddyfile.
  mac_address = "BC:24:11:00:02:60"
}
