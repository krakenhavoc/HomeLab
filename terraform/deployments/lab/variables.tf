variable "pve" {
  description = "Object containing the ProxMox Virtual Environment details"
  type = object({
    endpoint = string
    host     = string
  })
  default = {
    endpoint = "https://pve.labxp.io:8006"
    host     = "pve"
  }
}

variable "vm_disk_datastore_id" {
  description = "Datastore ID for the VM disk"
  type        = string
  default     = "ssd_1641G_thin"
}

variable "vm_cloudinit_datastore_id" {
  description = "Datastore ID for cloud-init snippets"
  type        = string
  default     = "ssd_1641G_thin"
}

variable "openclaw" {
  description = "Object containing the OpenClaw configuration"
  type = object({
    name_prefix    = optional(string, "openclaw")
    description    = optional(string, "OpenClaw Gateway - Managed by Terraform")
    tags           = optional(list(string), ["openclaw"])
    bios           = optional(string, "ovmf")
    cpu_cores      = optional(number, 4)
    memory_mb      = optional(number, 16384)
    os_disk_size   = optional(number, 50)
    disk_interface = optional(string, "virtio0")
    network_bridge = optional(string, "vmbr0")
    vlan_id        = optional(number, 200)
    admin_username = optional(string, "krkn")

    # This host is deliberately powered off and deliberately does not
    # autostart. Both default to true to match the module and the provider,
    # so the value that matters is the false set in env/lab/terraform.tfvars.
    #
    # These are live as of module v0.3.0. Before that the lab plan reported
    #   started = false -> true
    #   on_boot = false -> true
    # on openclaw every run, because with the attributes unwritten the
    # provider assumes a VM is meant to be running -- and the first apply
    # after the Cloudflare outage cleared duly started it.
    started = optional(bool, true)
    on_boot = optional(bool, true)
  })
  default = {}
}

# The static-addressing fields below (ipv4_address through mac_address) are
# openclaw-2's alone for now, deliberately. openclaw and pwnbox declare separate
# object types and are left on DHCP until someone actually wants them pinned;
# adding the fields to all three would imply a plan that does not exist.
#
# All five default to null/empty, and unset they change nothing: the module
# renders address = "dhcp", no gateway, no dns block and no mac_address, which
# is byte-for-byte what it rendered before the feature existed.
#
# WHY THIS EXISTS: nothing has ever decided openclaw-2's address except the
# DHCP server. A rebuild moved it from 192.168.200.36 to .37, and every SSH
# config, firewall rule and scribbled note that named .36 quietly pointed at
# a different machine (or nothing). A declared address survives a rebuild
# because the declaration, not the lease, is the source of truth.
variable "openclaw_2" {
  description = "Object containing the second OpenClaw host (upstream npm install, Codex provider)"
  type = object({
    name_prefix    = optional(string, "openclaw-2")
    description    = optional(string, "OpenClaw (upstream install, Codex) - Managed by Terraform")
    tags           = optional(list(string), ["openclaw"])
    bios           = optional(string, "ovmf")
    cpu_cores      = optional(number, 2)
    memory_mb      = optional(number, 4096)
    os_disk_size   = optional(number, 40)
    disk_interface = optional(string, "virtio0")
    network_bridge = optional(string, "vmbr0")
    vlan_id        = optional(number, 200)
    admin_username = optional(string, "krkn")

    # Static IPv4 address in CIDR form, e.g. "192.168.200.40/24". Null keeps
    # the host on DHCP. MUST be outside the VLAN 200 DHCP pool: a static
    # address inside the pool is handed out to the next machine that asks and
    # the conflict presents as intermittent, unattributable packet loss on
    # BOTH hosts, not as an obvious failure.
    ipv4_address = optional(string, null)
    ipv4_gateway = optional(string, null)

    # Set these whenever ipv4_address is set. A static address means no DHCP
    # lease, which means no resolvers from the lease either, which means an
    # empty resolv.conf on first boot -- and the cloud-init template for this
    # host fetches Node 24 and npm-installs openclaw@latest, so it does not
    # fail fast, it hangs.
    dns_servers = optional(list(string), [])
    dns_domain  = optional(string, null)

    # Only worth setting if something off-box keys on the MAC (a DHCP
    # reservation, a firewall rule). Redundant next to ipv4_address and a
    # second source of truth for the same fact -- see the module variable.
    mac_address = optional(string, null)
  })
  default = {}

  # These checks are duplicated in the module (pm-cloudinit-vm), on purpose.
  # The deployment pins the module by git ref, so until the ref that carries
  # the module-side validations is released and pinned here, these are the
  # ONLY thing standing between a typo and a VM that boots with no network.
  # They also fail earlier and name the deployment variable the operator
  # actually edited rather than a module input two hops away.
  validation {
    condition     = var.openclaw_2.ipv4_address == null || can(cidrnetmask(var.openclaw_2.ipv4_address))
    error_message = "openclaw_2.ipv4_address must carry a prefix length, e.g. \"192.168.200.40/24\" — a bare address produces cloud-init network config the guest cannot render, and openclaw-2 comes up with no address and no SSH, leaving the Proxmox console as the only way in."
  }

  validation {
    condition     = var.openclaw_2.ipv4_gateway == null || var.openclaw_2.ipv4_address != null
    error_message = "openclaw_2.ipv4_gateway requires openclaw_2.ipv4_address — on DHCP the gateway comes from the lease and a declared one is silently discarded, so the box would keep drifting between addresses while the config claimed it was pinned."
  }

  validation {
    condition     = var.openclaw_2.ipv4_address == null || length(var.openclaw_2.dns_servers) > 0
    error_message = "openclaw_2.ipv4_address requires openclaw_2.dns_servers — a static address means no DHCP lease and therefore no resolvers from it, and this host's cloud-init npm-installs openclaw from the network, so an empty resolv.conf reads as a first boot that never finishes rather than as a DNS fault."
  }

  validation {
    condition     = var.openclaw_2.mac_address == null || can(regex("^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$", var.openclaw_2.mac_address))
    error_message = "openclaw_2.mac_address must be six colon-separated hex octets, e.g. \"BC:24:11:00:02:40\" — Proxmox rejects any other form at apply time, long after the plan was reviewed and approved."
  }
}

variable "pwnbox" {
  description = "Object containing the Pwnbox configuration"
  type = object({
    name_prefix    = optional(string, "pwnbox")
    description    = optional(string, "CTF Pwnbox - Managed by Terraform")
    tags           = optional(list(string), ["ctf"])
    bios           = optional(string, "ovmf")
    cpu_cores      = optional(number, 4)
    memory_mb      = optional(number, 16384)
    os_disk_size   = optional(number, 50)
    disk_interface = optional(string, "virtio0")
    network_bridge = optional(string, "vmbr0")
    vlan_id        = optional(number, 200)
    admin_username = optional(string, "krkn")
  })
  default = {}
}

# cmd_and_ctrl and cmd_and_ctrl_dev MUST declare the same object type: they are
# combined into one map in locals and fed to a single for_each, and Terraform
# rejects a map whose element types differ. Add a field to one, add it to both.
variable "cmd_and_ctrl" {
  description = "cmd_and_ctrl production game server configuration"
  type = object({
    name_prefix    = optional(string, "cmd-and-ctrl")
    description    = optional(string, "cmd_and_ctrl game server - Managed by Terraform")
    tags           = optional(list(string), ["cmd-and-ctrl", "gameserver"])
    bios           = optional(string, "ovmf")
    cpu_cores      = optional(number, 2)
    memory_mb      = optional(number, 4096)
    os_disk_size   = optional(number, 40)
    data_disk_size = optional(number, 20)
    network_bridge = optional(string, "vmbr0")
    vlan_id        = optional(number, 200)
    admin_username = optional(string, "krkn")
    fqdn           = optional(string, "cmd.labxp.io")
    # CMDCTRL_ENV. "prod" is the fail-closed default: it is what the server
    # assumes when the variable is unset, and it is the value that exposes no
    # dev-only features. See cmd_and_ctrl ADR 0023.
    cmdctrl_env = optional(string, "prod")
  })
  default = {}

  validation {
    condition     = contains(["prod", "dev"], var.cmd_and_ctrl.cmdctrl_env)
    error_message = "cmdctrl_env must be \"prod\" or \"dev\" — the server exits on any other value."
  }
}

variable "cmd_and_ctrl_dev" {
  description = "cmd_and_ctrl develop preview server configuration"
  type = object({
    name_prefix    = optional(string, "cmd-and-ctrl-dev")
    description    = optional(string, "cmd_and_ctrl develop preview - Managed by Terraform")
    tags           = optional(list(string), ["cmd-and-ctrl", "gameserver", "dev"])
    bios           = optional(string, "ovmf")
    cpu_cores      = optional(number, 2)
    memory_mb      = optional(number, 4096)
    os_disk_size   = optional(number, 40)
    data_disk_size = optional(number, 20)
    network_bridge = optional(string, "vmbr0")
    vlan_id        = optional(number, 200)
    admin_username = optional(string, "krkn")
    fqdn           = optional(string, "cmd-dev.labxp.io")
    cmdctrl_env    = optional(string, "dev")
  })
  default = {}

  validation {
    condition     = contains(["prod", "dev"], var.cmd_and_ctrl_dev.cmdctrl_env)
    error_message = "cmdctrl_env must be \"prod\" or \"dev\" — the server exits on any other value."
  }
}

variable "cmd_and_ctrl_admin_token" {
  description = "Admin token for cmd_and_ctrl production (CMDCTRL_ADMIN_TOKEN). 16+ chars."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.cmd_and_ctrl_admin_token) >= 16
    error_message = "The server refuses to start with an admin token shorter than 16 characters."
  }
}

variable "cmd_and_ctrl_dev_admin_token" {
  description = <<-EOT
    Admin token for the cmd_and_ctrl develop preview (CMDCTRL_ADMIN_TOKEN).
    MUST differ from production's: the preview environment exposes card
    spawning and seat swapping to any admin session, so a shared token would
    make a leak from the low-trust box a compromise of the live table.
  EOT
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.cmd_and_ctrl_dev_admin_token) >= 16
    error_message = "The server refuses to start with an admin token shorter than 16 characters."
  }

  validation {
    condition     = var.cmd_and_ctrl_dev_admin_token != var.cmd_and_ctrl_admin_token
    error_message = "The develop admin token must not be the same as production's."
  }
}

variable "cmd_and_ctrl_tunnel_token" {
  description = <<-EOT
    Cloudflare Tunnel token for cmd.labxp.io. Generated by hand in the Zero
    Trust dashboard and passed in as a secret. Production's tunnel is
    deliberately NOT managed by Terraform: importing a tunnel that is currently
    serving traffic is a risk with no payoff. The develop tunnel IS managed
    here, so it needs no secret.
  EOT
  type        = string
  sensitive   = true
}

variable "cloudflare_api_token" {
  description = <<-EOT
    Cloudflare API token used to manage the develop tunnel, its ingress
    config, its DNS record, and the cmd_and_ctrl R2 backup buckets. Four
    permissions:

      Account : Cloudflare One Connector: cloudflared : Edit
      Account : Workers R2 Storage : Edit
      Zone    : DNS : Edit    (on labxp.io only)
      Zone    : Zone : Read   (on labxp.io only)

    THE R2 PERMISSION IS NOT OPTIONAL and this block used to claim it was --
    it read "two permissions, nothing broader", naming only cloudflared and
    DNS. That was wrong from the moment cloudflare_r2_bucket landed
    (HomeLab#58): the buckets were created by this token on 2026-09-19, which
    is only possible with R2 write. Anyone reissuing the token from the old
    description would have produced an under-scoped token, watched R2 fail,
    and had no reason to suspect the documentation.

    Zone:Read is listed because the "Edit zone DNS" template in the dashboard
    includes it and because anything doing an ACME DNS-01 challenge against
    this zone needs it to resolve the zone ID from its name (see
    docs/gateway.md). Harmless if the tunnel and DNS work without it.

    CHECK CLIENT IP ADDRESS FILTERING BEFORE ANYTHING ELSE when this token
    starts returning 401. On 2026-09-21 the whole lab pipeline failed on
    three Cloudflare 401s with code 10000 while the GitHub secret had not
    been touched since 2026-09-10 and the same token had applied cleanly on
    the 19th and 20th. The token was valid, correctly scoped and not
    expired. Its IP filter no longer matched: the plan runs on the
    self-hosted runner inside this network, so every Cloudflare call carries
    the lab's WAN address, and that address changes on its own.

    This is the failure mode to expect here, and it is not self-announcing.
    The token looks fine in the dashboard, `/user/tokens/verify` answers from
    a different machine may look fine too, and nothing in the repo changed.
    Only calls from the runner fail. Re-check the filter after any ISP lease
    change, router replacement or WAN reconfiguration.

    Expiry is worth avoiding for the same reason but was NOT the cause here;
    an earlier version of this note claimed it was, which would have sent the
    next person to reissue a token that was never the problem.

    Either way the blast radius is the whole deployment, not just Cloudflare:
    an auth failure fails the plan, which blocks every Proxmox change in this
    root module too.

    Note the status code when diagnosing: 401 code 10000 is an invalid,
    revoked or expired token -- OR a valid one whose client IP filter
    excludes the caller, which is indistinguishable from the response alone.
    403 code 10000 is a token that authenticates but lacks a permission, or a
    correctly permissioned token scoped to a different account (see Account
    Resources below).

    The account permission was called "Cloudflare Tunnel" and tokens holding
    it still work, but new tokens are issued under the Cloudflare One
    Connector name, so that is what the dashboard picker offers. The API
    accepts any of "Cloudflare One Connectors Write", "Cloudflare One
    Connector: cloudflared Write" or "Cloudflare Tunnel Write" for
    POST /accounts/{id}/cfd_tunnel; the UI's "Edit" is the API's "Write".

    Every tunnel permission is Account-scoped, so it does not appear while a
    permission row's scope selector is set to Zone. The token must also list
    this account under Account Resources -- a correctly permissioned token
    scoped to a different account returns the same 403 code 10000
    "Authentication error" as a token missing the permission entirely.
  EOT
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account ID that owns the Zero Trust tunnels."
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Cloudflare zone ID for labxp.io."
  type        = string
}

variable "cmd_and_ctrl_github_token" {
  description = <<-EOT
    Fine-grained GitHub PAT for the in-app bug-report button (cmd_and_ctrl
    ADR 0017): Issues:write on krakenhavoc/cmd_and_ctrl only. Seeds the
    first-boot env file in the cloud-init template so a rebuilt VM starts
    with bug reporting live. Flows in as TF_VAR_cmd_and_ctrl_github_token
    from the CMD_AND_CTRL_GITHUB_TOKEN environment secret (lab), same as
    the admin/tunnel tokens. The steady-state copy on the host is synced
    by the cmd_and_ctrl repo's CD pipeline from that repo's own
    CMDCTRL_GITHUB_TOKEN Actions secret (managed by hand — deliberately
    not Terraform; one secret didn't justify a github-provider
    credential). Empty string (the default) writes no env line.
  EOT
  type        = string
  sensitive   = true
  default     = ""
}

variable "windows11" {
  description = "Object containing the Windows 11 VM configuration"
  type = object({
    name_prefix    = optional(string, "win11")
    description    = optional(string, "Windows 11 - Managed by Terraform")
    tags           = optional(list(string), ["windows"])
    cpu_cores      = optional(number, 4)
    memory_mb      = optional(number, 8192)
    os_disk_size   = optional(number, 64)
    network_bridge = optional(string, "vmbr0")
    vlan_id        = optional(number, null)
  })
  default = {}
}
