vm_disk_datastore_id      = "ssd_1641G_thin"
vm_cloudinit_datastore_id = "ssd_1641G_thin"

# Values copied from lab/env/lab as they were; names are frozen.
cmd_and_ctrl = {
  name_prefix    = "cmd-and-ctrl"
  description    = "cmd_and_ctrl game server - Managed by Terraform"
  tags           = ["cmd-and-ctrl", "gameserver"]
  bios           = "ovmf"
  cpu_cores      = 2
  memory_mb      = 4096
  os_disk_size   = 40
  data_disk_size = 20
  network_bridge = "vmbr0"
  vlan_id        = 200
  admin_username = "krkn"
  fqdn           = "cmd.labxp.io"
  cmdctrl_env    = "prod"
  backup_bucket  = "cmd-and-ctrl-backup-prod"
  # Tunnel made by hand; token from CMD_AND_CTRL_TUNNEL_TOKEN.
  manage_tunnel = false
  bug_reports   = true
}
