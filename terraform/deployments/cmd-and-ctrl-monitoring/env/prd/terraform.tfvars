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

  # Pinned (Proxmox OUI); the router's DHCP reservation is keyed on it.
  mac_address = "BC:24:11:9F:CF:67"

  # The router's DHCP reservation for the pinned MAC above (VLAN 200, outside
  # the pool). The two must stay in step: change one, change the other.
  ipv4_address = "192.168.200.11/24"

  # Read from the live cmd_and_ctrl dev VM on VLAN 200.
  ipv4_gateway = "192.168.200.1"
  dns_servers  = ["192.168.10.11", "192.168.10.12"]
  dns_domain   = "lan.labxp.io"

  # Admitted on 3000 (Grafana), 9091 and 3101 (push). 192.168.200.0/24 is
  # VLAN 200, where the cmd_and_ctrl VMs push from; 192.168.1.0/24 is the
  # owner's wired LAN, where Grafana is viewed from. Adjust as needed (a VPN
  # range, say). The host firewall only reads this at first boot; afterwards,
  # edit /etc/nftables.conf on the VM.
  lan_cidrs = ["192.168.200.0/24", "192.168.1.0/24"]
}
