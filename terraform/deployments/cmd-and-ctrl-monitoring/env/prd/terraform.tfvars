vm_disk_datastore_id      = "ssd_1641G_thin"
vm_cloudinit_datastore_id = "ssd_1641G_thin"

# cmd_and_ctrl monitoring VM (cmd_and_ctrl ADR 0123 §6). One instance watches
# both cmd_and_ctrl environments.
monitoring = {
  name_prefix    = "cmd-and-ctrl-monitoring"
  tags           = ["cmd-and-ctrl", "monitoring"]
  cpu_cores      = 2
  memory_mb      = 4096
  os_disk_size   = 20
  data_disk_size = 80
  # Same VLAN as the cmd_and_ctrl VMs, so their pushes stay on-segment.
  vlan_id = 200

  # --- OWNER: replace every 192.0.2.x below before the first plan ---------
  # RFC 5737 documentation placeholders; variables.tf fails the plan while
  # any remains. Check the live DHCP scope first (docs/network-setup.md):
  # the address must be outside the pool and unused.
  ipv4_address = "192.0.2.20/24"
  ipv4_gateway = "192.0.2.1"
  dns_servers  = ["192.0.2.53"]
  dns_domain   = "labxp.io"
  # Admitted on 3000 (Grafana), 9091 and 3101 (push): the cmd_and_ctrl VLAN
  # and wherever Grafana is viewed from (client VLAN, VPN).
  lan_cidrs = ["192.0.2.0/24"]
}
