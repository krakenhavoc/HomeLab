vm_disk_datastore_id      = "ssd_1641G_thin"
vm_cloudinit_datastore_id = "ssd_1641G_thin"

# Develop preview. Same shape as prd on purpose: it rehearses prd.
cmd_and_ctrl = {
  name_prefix    = "cmd-and-ctrl-dev"
  description    = "cmd_and_ctrl develop preview - Managed by Terraform"
  tags           = ["cmd-and-ctrl", "gameserver", "dev"]
  bios           = "ovmf"
  cpu_cores      = 2
  memory_mb      = 4096
  os_disk_size   = 40
  data_disk_size = 20
  network_bridge = "vmbr0"
  vlan_id        = 200
  admin_username = "krkn"
  fqdn           = "cmd-dev.labxp.io"
  cmdctrl_env    = "dev"
  backup_bucket  = "cmd-and-ctrl-backup-dev"
  manage_tunnel  = true
  # Own token (dev project), so bug reports work in the preview too.
  bug_reports = true
}
