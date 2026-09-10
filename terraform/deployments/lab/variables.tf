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
  })
  default = {}
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
    fqdn           = optional(string, "dev.cmd.labxp.io")
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
    Cloudflare API token used to manage the develop tunnel, its ingress config
    and its DNS record. Two permissions, nothing broader:

      Account : Cloudflare One Connector: cloudflared : Edit
      Zone    : DNS : Edit   (on labxp.io only)

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
