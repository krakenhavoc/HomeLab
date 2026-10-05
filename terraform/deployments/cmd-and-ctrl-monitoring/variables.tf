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

# Addressing is static and declared here, not DHCP (cmd_and_ctrl ADR 0123
# §6): two Alloy configs and cmd_and_ctrl's CMDCTRL_MONITORING_URL point at
# this address, and a rotted lease is cmd_and_ctrl#598 item 1. The address
# MUST be outside the VLAN's DHCP pool and unused; see docs/network-setup.md.
variable "monitoring" {
  description = "The cmd_and_ctrl monitoring VM (Prometheus, Loki, Grafana, Alertmanager)"
  type = object({
    name_prefix    = optional(string, "cmd-and-ctrl-monitoring")
    description    = optional(string, "cmd_and_ctrl monitoring (Prometheus, Loki, Grafana, Alertmanager) - Managed by Terraform")
    tags           = optional(list(string), ["cmd-and-ctrl", "monitoring"])
    bios           = optional(string, "ovmf")
    cpu_cores      = optional(number, 2)
    memory_mb      = optional(number, 4096)
    os_disk_size   = optional(number, 20)
    data_disk_size = optional(number, 80)
    network_bridge = optional(string, "vmbr0")
    # The cmd_and_ctrl VMs' VLAN, so their pushes need no inter-VLAN rule.
    vlan_id        = optional(number, 200)
    admin_username = optional(string, "krkn")

    # CIDR form with the VLAN's real prefix, e.g. "192.0.2.20/24".
    ipv4_address = string
    # Bare address, e.g. "192.0.2.1".
    ipv4_gateway = string
    # A static address gets no resolvers from a lease. First boot installs
    # Docker and pulls images, so an empty resolv.conf hangs it.
    dns_servers = list(string)
    dns_domain  = optional(string, null)

    # Sources the host firewall admits on 3000 (Grafana), 9091 and 3101
    # (push): the app hosts' VLAN and the LAN/VPN ranges Grafana is viewed
    # from. IPv4 CIDRs.
    lan_cidrs = list(string)
  })

  validation {
    condition     = can(cidrnetmask(var.monitoring.ipv4_address))
    error_message = "monitoring.ipv4_address must carry a prefix length, e.g. \"192.0.2.20/24\"; a bare address renders network config the guest cannot apply."
  }

  # env/prd ships with documentation-range placeholders (RFC 5737), so a plan
  # fails here until the owner has filled in the real network.
  validation {
    condition = !anytrue([
      for v in concat([var.monitoring.ipv4_address, var.monitoring.ipv4_gateway], var.monitoring.dns_servers, var.monitoring.lan_cidrs) :
      startswith(v, "192.0.2.")
    ])
    error_message = "monitoring still holds the 192.0.2.x documentation placeholders. Set ipv4_address (free, outside the VLAN's DHCP pool), ipv4_gateway, dns_servers and lan_cidrs in env/prd/terraform.tfvars."
  }

  validation {
    condition     = can(cidrhost("${var.monitoring.ipv4_gateway}/32", 0))
    error_message = "monitoring.ipv4_gateway must be a bare IPv4 address, e.g. \"192.0.2.1\"."
  }

  validation {
    condition     = length(var.monitoring.dns_servers) > 0
    error_message = "monitoring.dns_servers is required with a static address."
  }

  validation {
    condition     = length(var.monitoring.lan_cidrs) > 0 && alltrue([for c in var.monitoring.lan_cidrs : can(cidrnetmask(c))])
    error_message = "monitoring.lan_cidrs must list at least one IPv4 CIDR, e.g. \"192.0.2.0/24\"."
  }
}

# --- Secrets (Bitwarden, env/prd/secrets.env -> TF_VAR_*) --------------------
# Written once by cloud-init to /etc/monitoring on the VM. The VM ignores
# initialization changes, so changing a value here alone does nothing to a
# running host: rotate on the host (cmd-and-ctrl-monitoring/README.md).

variable "cmdctrl_monitoring_grafana_admin_password" {
  description = "Grafana's admin password (user admin)."
  type        = string
  sensitive   = true

  validation {
    condition     = length(var.cmdctrl_monitoring_grafana_admin_password) >= 16 && !can(regex("['\\n]", var.cmdctrl_monitoring_grafana_admin_password))
    error_message = "cmdctrl_monitoring_grafana_admin_password must be at least 16 characters, with no single quote or newline (it is written single-quoted to an env file)."
  }
}

variable "cmdctrl_monitoring_discord_webhook_url" {
  description = "Discord webhook Alertmanager posts to, https://discord.com/api/webhooks/<id>/<token>."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^https://(discord\\.com|discordapp\\.com)/api/webhooks/[0-9]+/[A-Za-z0-9_-]+$", var.cmdctrl_monitoring_discord_webhook_url))
    error_message = "cmdctrl_monitoring_discord_webhook_url must be a Discord webhook URL, https://discord.com/api/webhooks/<id>/<token>, with nothing after the token."
  }
}

variable "cmdctrl_monitoring_push_hash_prod" {
  description = "bcrypt hash of the prod app host's push password (Caddy basic auth user \"prod\"). Make it with `caddy hash-password`."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^\\$2[aby]\\$[0-9]{2}\\$[./A-Za-z0-9]{53}$", var.cmdctrl_monitoring_push_hash_prod))
    error_message = "cmdctrl_monitoring_push_hash_prod must be a bcrypt hash ($2a$14$...), as printed by `caddy hash-password`; never the plaintext."
  }
}

variable "cmdctrl_monitoring_push_hash_dev" {
  description = "bcrypt hash of the dev app host's push password (Caddy basic auth user \"dev\"). Make it with `caddy hash-password`."
  type        = string
  sensitive   = true

  validation {
    condition     = can(regex("^\\$2[aby]\\$[0-9]{2}\\$[./A-Za-z0-9]{53}$", var.cmdctrl_monitoring_push_hash_dev))
    error_message = "cmdctrl_monitoring_push_hash_dev must be a bcrypt hash ($2a$14$...), as printed by `caddy hash-password`; never the plaintext."
  }
}
