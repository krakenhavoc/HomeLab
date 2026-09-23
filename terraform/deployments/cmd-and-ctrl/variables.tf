variable "pve" {
  description = "Proxmox endpoint and node"
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
  description = "Datastore ID for the VM disks"
  type        = string
}

variable "vm_cloudinit_datastore_id" {
  description = "Datastore ID for cloud-init"
  type        = string
}

variable "cmd_and_ctrl" {
  description = "cmd_and_ctrl game server for this workspace"
  type = object({
    name_prefix    = string
    description    = string
    tags           = list(string)
    bios           = optional(string, "ovmf")
    cpu_cores      = optional(number, 2)
    memory_mb      = optional(number, 4096)
    os_disk_size   = optional(number, 40)
    data_disk_size = optional(number, 20)
    network_bridge = optional(string, "vmbr0")
    vlan_id        = optional(number, 200)
    admin_username = optional(string, "krkn")
    fqdn           = string
    # CMDCTRL_ENV. See cmd_and_ctrl ADR 0023.
    cmdctrl_env = string
    # Frozen: existing bucket names use prod/dev.
    backup_bucket = string
    # Tunnel, ingress and DNS managed here (dev). prd's tunnel is hand-made.
    manage_tunnel = optional(bool, false)
    # In-app bug reports (ADR 0017). Off for the low-trust preview.
    bug_reports = optional(bool, false)
  })

  validation {
    condition     = contains(["prod", "dev"], var.cmd_and_ctrl.cmdctrl_env)
    error_message = "cmdctrl_env must be \"prod\" or \"dev\"; the server exits on any other value."
  }
}

variable "cmd_and_ctrl_admin_token" {
  description = "CMDCTRL_ADMIN_TOKEN. Per environment; dev and prd must differ."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.cmd_and_ctrl_admin_token) >= 16
    error_message = "The server refuses to start with an admin token shorter than 16 characters."
  }
}

variable "cmd_and_ctrl_tunnel_token" {
  description = "Connector token for a hand-made tunnel (prd). Unused when manage_tunnel is set."
  type        = string
  sensitive   = true
  default     = ""

  validation {
    condition     = var.cmd_and_ctrl.manage_tunnel || length(var.cmd_and_ctrl_tunnel_token) > 0
    error_message = "cmd_and_ctrl_tunnel_token is required when the tunnel isn't managed here."
  }
}

variable "cmd_and_ctrl_github_token" {
  description = "Issues:write PAT for bug reports. Only used when bug_reports is set."
  type        = string
  sensitive   = true
  default     = ""
}

variable "cloudflare_api_token" {
  description = <<-EOT
    Cloudflare token for the tunnel, DNS and R2 buckets:
      Account : Cloudflare One Connector: cloudflared : Edit
      Account : Workers R2 Storage : Edit
      Zone    : DNS : Edit, Zone : Read (labxp.io)
    401 code 10000 from the runner: check the token's client IP filter first
    (see lab history, 2026-09-21).
  EOT
  type        = string
  sensitive   = true
}

variable "cloudflare_account_id" {
  description = "Cloudflare account that owns the tunnels and buckets"
  type        = string
}

variable "cloudflare_zone_id" {
  description = "Zone ID for labxp.io"
  type        = string
}
