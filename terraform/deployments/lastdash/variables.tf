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

    # Static, outside the VLAN 201 DHCP pool: the gateway's Caddyfile pins
    # this address, so a rebuild that drew a different lease would leave
    # lastdash.labxp.io pointing at nothing.
    ipv4_address = optional(string, null)
    ipv4_gateway = optional(string, null)
    dns_servers  = optional(list(string), [])
    dns_domain   = optional(string, null)
  })
  default = {}

  validation {
    condition     = var.lastdash_host.ipv4_address != null && can(cidrnetmask(var.lastdash_host.ipv4_address))
    error_message = "lastdash_host.ipv4_address is required and must carry a prefix length, e.g. \"192.168.201.20/24\" — the gateway's Caddyfile proxies to this address, so it cannot be a DHCP lease."
  }

  validation {
    condition     = var.lastdash_host.ipv4_gateway != null && can(cidrnetmask("${var.lastdash_host.ipv4_gateway}/32"))
    error_message = "lastdash_host.ipv4_gateway is required and must be a bare IPv4 address with no prefix, e.g. \"192.168.201.1\"."
  }

  validation {
    condition     = length(var.lastdash_host.dns_servers) > 0
    error_message = "lastdash_host.dns_servers is required with a static address — first boot pulls container images, and an empty resolv.conf hangs rather than failing."
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
    error_message = "lastdash_token_encryption_secret must be at least 16 characters (the API refuses shorter keys). Check that lastdash-deploy.yaml passes secrets.LASTDASH_TOKEN_ENCRYPTION_SECRET."
  }
}

variable "lastdash_nextauth_secret" {
  description = "NEXTAUTH_SECRET for session signing."
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.lastdash_nextauth_secret) >= 16
    error_message = "lastdash_nextauth_secret is empty or too short — check that lastdash-deploy.yaml passes secrets.LASTDASH_NEXTAUTH_SECRET."
  }
}

variable "lastdash_postgres_password" {
  description = "Password for the stack's internal Postgres (never exposed outside the VM)."
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.lastdash_postgres_password) >= 16
    error_message = "lastdash_postgres_password is empty or too short — check that lastdash-deploy.yaml passes secrets.LASTDASH_POSTGRES_PASSWORD."
  }
}

variable "lastdash_ghcr_token" {
  description = "GitHub classic PAT with read:packages only. The LastDash repo is private, so its GHCR images are too; the host logs in once to pull them."
  type        = string
  sensitive   = true
  validation {
    condition     = length(var.lastdash_ghcr_token) > 0
    error_message = "lastdash_ghcr_token is empty — check that lastdash-deploy.yaml passes secrets.LASTDASH_GHCR_TOKEN."
  }
}
