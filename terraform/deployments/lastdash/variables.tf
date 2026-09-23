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
}

variable "vm_cloudinit_datastore_id" {
  description = "Datastore ID for cloud-init snippets"
  type        = string
}

variable "lastdash_host" {
  description = "Configuration for the LastDash app host (docker compose: web, api, postgres, redis)"
  type = object({
    env            = optional(string, "prod")
    name_prefix    = optional(string, "lastdash")
    description    = optional(string, "LastDash app host")
    tags           = optional(list(string), ["apps"])
    bios           = optional(string, "ovmf")
    cpu_cores      = optional(number, 2)
    memory_mb      = optional(number, 4096)
    os_disk_size   = optional(number, 40)
    disk_interface = optional(string, "virtio0")
    network_bridge = optional(string, "vmbr0")
    vlan_id        = optional(number, 201)

    # Addressing is DHCP with a static lease on the firewall, keyed on this
    # pinned MAC -- the firewall is the single source of truth for addresses.
    # Pinned because a rebuild would otherwise draw a new MAC, lose the lease,
    # and leave the gateway's Caddyfile upstream pointing at nothing. Do not
    # also set a static address in cloud-init (see pm-cloudinit-vm's
    # vm_mac_address notes: two sources of truth for one fact).
    mac_address = optional(string, null)
  })
  default = {}

  validation {
    condition     = var.lastdash_host.mac_address != null && can(regex("^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$", var.lastdash_host.mac_address))
    error_message = "lastdash_host.mac_address is required, as six colon-separated hex octets under Proxmox's OUI, e.g. \"BC:24:11:00:02:50\" — the firewall's static DHCP lease is keyed on it, and a generated MAC would change on rebuild."
  }
}

# ─── App secrets (GitHub environment secrets → TF_VAR_*) ─────────────────────
# Written once by cloud-init to /etc/lastdash/env (0600 root). Rotating one
# means editing that file on the host and restarting the stack; changing the
# value here alone does nothing (initialization is ignore_changes'd).

variable "lastdash_token_encryption_secret" {
  description = "TOKEN_ENCRYPTION_SECRET. Prod starts from a copy of the dev database, so this must be the dev value or stored Slack/Teams tokens become unreadable."
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.lastdash_token_encryption_secret) >= 16
    error_message = "lastdash_token_encryption_secret must be at least 16 characters (the API refuses shorter keys). Check LASTDASH_TOKEN_ENCRYPTION_SECRET in the prd environment."
  }
}

variable "lastdash_nextauth_secret" {
  description = "NEXTAUTH_SECRET for session signing."
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.lastdash_nextauth_secret) >= 16
    error_message = "lastdash_nextauth_secret is empty or too short — set LASTDASH_NEXTAUTH_SECRET in the prd environment."
  }
}

variable "lastdash_postgres_password" {
  description = "Password for the stack's internal Postgres (never exposed outside the VM)."
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.lastdash_postgres_password) >= 16
    error_message = "lastdash_postgres_password is empty or too short — set LASTDASH_POSTGRES_PASSWORD in the prd environment."
  }
}

variable "lastdash_ghcr_token" {
  description = "GitHub classic PAT with read:packages only. The LastDash repo is private, so its GHCR images are too; the host logs in once to pull them."
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.lastdash_ghcr_token) > 0
    error_message = "lastdash_ghcr_token is empty — set LASTDASH_GHCR_TOKEN in the prd environment."
  }
}
