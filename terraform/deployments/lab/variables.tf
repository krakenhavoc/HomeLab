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

# Only kept so lab can forget the cmd_and_ctrl Cloudflare resources. Drop it
# with the provider once that has applied.
variable "cloudflare_api_token" {
  description = "Cloudflare token (unused by lab's own resources)"
  type        = string
  sensitive   = true
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
