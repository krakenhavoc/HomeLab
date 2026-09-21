pve = {
  endpoint = "https://pve.labxp.io:8006"
  host     = "pve"
}
vm_disk_datastore_id      = "ssd_1641G_thin"
vm_cloudinit_datastore_id = "ssd_1641G_thin"
openclaw = {
  name_prefix = "openclaw"
  description = "OpenClaw Gateway - Managed by Terraform"
  tags        = ["openclaw"]
  bios        = "ovmf"
  cpu_cores   = 4
  memory_mb   = 16384
  # Matches the disk's real size — it was grown to 100G out-of-band
  # and the config had drifted at 50.
  os_disk_size   = 100
  disk_interface = "virtio0"
  network_bridge = "vmbr0"
  vlan_id        = 200
  admin_username = "krkn"

  # --- Powered off on purpose: COMMENTED UNTIL MODULE v0.3.0 ----------------
  # openclaw is shut down deliberately and is not meant to come back on its
  # own. Both values are decided; they stay commented only because the module
  # ref in main.tf is still v0.2.0, which does not declare vm_started or
  # vm_on_boot. See the block at the openclaw module call.
  #
  # on_boot is set alongside started, not instead of it. started=false with
  # on_boot left true means the host is off now and returns by itself after
  # the next node reboot, which is not "powered off" in any useful sense.
  #
  # started = false
  # on_boot = false
}
# Second OpenClaw host: upstream installer (npm) instead of the fork source
# build, Codex instead of Azure Foundry. Nothing is compiled on this VM, so it
# was first sized at 4 GB on upstream's guidance rather than copying the fork
# box's 16 GB. See variables.tf for that reasoning.
#
# It now runs two Gateway instances -- the default profile and a `work`
# profile on port 19789 -- and the installer caps each one's V8 old space at
# 2048 MiB before their Codex and Claude Code child processes are counted.
# 4 GB was oversubscribed. The host was raised to 16 GB out-of-band; this
# value follows that change so a later apply does not revert it.
openclaw_2 = {
  name_prefix = "openclaw-2"
  description = "OpenClaw (upstream install, Codex) - Managed by Terraform"
  tags        = ["openclaw"]
  bios        = "ovmf"
  # Matches the host's real core count — it was raised to 8 out-of-band, the
  # same way the memory below was raised to 16 GB, and the config had drifted
  # at 2. Following the change rather than reverting it: the pending plan
  # wanted `cores = 8 -> 2`, and applying that would have cut the box to a
  # quarter of its CPU while it runs two Gateway instances plus their Codex
  # and Claude Code child processes.
  cpu_cores      = 8
  memory_mb      = 16384
  os_disk_size   = 40
  disk_interface = "virtio0"
  network_bridge = "vmbr0"
  vlan_id        = 200
  admin_username = "krkn"

  # --- Static addressing: DELIBERATELY COMMENTED OUT ------------------------
  # Left inert because nobody has supplied the four facts these lines need,
  # and every one of them is a fact about the VLAN 200 network that cannot be
  # guessed from inside this repo. A wrong guess here is not a failed plan; it
  # is an IP conflict on a live segment, which presents as intermittent packet
  # loss on openclaw-2 AND on whatever else holds the address -- neither of
  # which points at this file.
  #
  # To turn it on, the operator supplies, and verifies against the router:
  #
  #   1. ipv4_address — a free VLAN 200 address OUTSIDE the DHCP pool, in CIDR
  #      form with the VLAN's real prefix length. Outside the pool is the part
  #      that matters: an address inside the pool is not reserved by being
  #      written here, and the DHCP server will hand it to the next machine
  #      that asks. Check the pool's range on the router; do not infer it from
  #      the addresses lab VMs happen to have been given.
  #   2. ipv4_gateway — the VLAN 200 gateway. Bare address, no prefix.
  #   3. dns_servers  — both Pi-hole addresses. Both, not one: a static host
  #      has no DHCP lease to fall back on, so a single Pi-hole means every
  #      name lookup on this box stops while that Pi-hole reboots.
  #   4. dns_domain   — optional. Drop the line if short names are not used.
  #
  # Filling these in REPLACES THE VM. openclaw-2 is on DHCP today, so applying
  # a static address rewrites the cloud-init drive, and cloud-init network
  # config is first-boot-only -- the provider rebuilds the guest to make it
  # take. That also discards the Codex OAuth login, which is a manual
  # device-code step (see the module call's comment in main.tf). Expect it,
  # confirm it in the plan, and have the device-code step ready.
  #
  # Nothing happens until the module ref in main.tf is bumped to v0.3.0 and
  # the matching pass-through lines there are uncommented; the fields below
  # are declared in variables.tf but reach no module until then.
  #
  # ipv4_address = "192.168.200.XX/YY" # outside the DHCP pool
  # ipv4_gateway = "192.168.200.X"     # VLAN 200 gateway
  # dns_servers  = ["192.168.X.X", "192.168.X.X"] # both Pi-holes
  # dns_domain   = "labxp.io"
}
pwnbox = {
  name_prefix    = "pwnbox"
  description    = "CTF Pwnbox - Managed by Terraform"
  tags           = ["ctf"]
  bios           = "ovmf"
  cpu_cores      = 4
  memory_mb      = 8192
  os_disk_size   = 50
  disk_interface = "virtio0"
  network_bridge = "vmbr0"
  vlan_id        = 200
  admin_username = "krkn"
}
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
}
# Develop preview. Same shape as production on purpose — it exists to rehearse
# production, and a preview sized differently rehearses something else. The
# memory figure is the one worth arguing with: two 4 GB game servers on this
# host is ~4 GB more committed than before, and the Scryfall index is the bulk
# of it. Drop to 3072 if the node is tight.
cmd_and_ctrl_dev = {
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
}
windows11 = {
  name_prefix    = "win11"
  description    = "Windows 11 - Managed by Terraform"
  tags           = ["windows"]
  cpu_cores      = 4
  memory_mb      = 16384
  os_disk_size   = 64
  network_bridge = "vmbr0"
  vlan_id        = 99
}
