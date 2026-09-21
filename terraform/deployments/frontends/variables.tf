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

# The static-addressing fields below (ipv4_address through dns_domain) default
# to null/empty, and unset they change nothing: the module renders
# address = "dhcp", no gateway and no dns block, which is byte-for-byte what it
# rendered before they existed. Nothing here reaches the module until PR #65
# merges, main is tagged v0.3.0, the ref in main.tf is bumped and the
# pass-through lines there are uncommented -- see that file.
#
# WHY THIS EXISTS: this host is becoming the lab gateway (docs/gateway.md).
# Every internal DNS name is about to resolve to it, which makes its address a
# published fact that a dozen Pi-hole records depend on. A DHCP lease is not a
# published fact -- openclaw-2 came back on a different address after a rebuild
# and everything naming the old one quietly pointed at nothing. The same
# rebuild here would silently break every name in the lab at once.
variable "pfe_host" {
  description = "Configuration for the Plex host VM"
  type = object({
    env            = optional(string, "dev")
    name_prefix    = optional(string, "pfe")
    description    = optional(string, "Private Frontends Host")
    tags           = optional(list(string), ["apps"])
    bios           = optional(string, "ovmf")
    cpu_cores      = optional(number, 2)
    memory_mb      = optional(number, 4096)
    os_disk_size   = optional(number, 30)
    disk_interface = optional(string, "virtio0")
    network_bridge = optional(string, "vmbr0")
    vlan_id        = optional(number, 201)

    # Static IPv4 address in CIDR form. MUST be outside the VLAN 201 DHCP
    # pool: an address inside the pool is not reserved by being written here,
    # and the DHCP server will hand it to the next machine that asks. The
    # resulting conflict presents as intermittent, unattributable packet loss
    # on BOTH hosts, not as an obvious failure.
    ipv4_address = optional(string, null)
    ipv4_gateway = optional(string, null)

    # Set these whenever ipv4_address is set. A static address means no DHCP
    # lease, which means no resolvers from the lease either, which means an
    # empty resolv.conf on first boot -- and this host's cloud-init installs
    # Docker from download.docker.com and pulls images, so it does not fail
    # fast, it hangs.
    dns_servers = optional(list(string), [])
    dns_domain  = optional(string, null)
  })
  default = {}

  # Duplicated from the module (pm-cloudinit-vm) on purpose. This deployment
  # pins the module by git ref, so until the ref carrying the module-side
  # validations is released and pinned here, these are the ONLY thing between
  # a typo and a VM that boots with no network. They also fail earlier and name
  # the variable the operator actually edited.
  validation {
    condition     = var.pfe_host.ipv4_address == null || can(cidrnetmask(var.pfe_host.ipv4_address))
    error_message = "pfe_host.ipv4_address must carry a prefix length, e.g. \"192.168.201.14/24\" — a bare address produces cloud-init network config the guest cannot render, and pfe comes up with no address and no SSH, leaving the Proxmox console as the only way in."
  }

  validation {
    condition     = var.pfe_host.ipv4_gateway == null || var.pfe_host.ipv4_address != null
    error_message = "pfe_host.ipv4_gateway requires pfe_host.ipv4_address — on DHCP the gateway comes from the lease and a declared one is silently discarded, so the host would keep drifting between addresses while the config claimed it was pinned."
  }

  validation {
    # Appending /32 turns a bare address into something cidrnetmask can parse;
    # a value that already carries a prefix (the paste-the-CIDR-twice mistake)
    # becomes "a.b.c.d/24/32" and fails, which is the point.
    condition     = var.pfe_host.ipv4_gateway == null || can(cidrnetmask("${var.pfe_host.ipv4_gateway}/32"))
    error_message = "pfe_host.ipv4_gateway must be a bare IPv4 address with no prefix length, e.g. \"192.168.201.1\" — Proxmox rejects an ipconfig0 line whose gw= carries a netmask, and the VM fails to start rather than starting misconfigured."
  }

  validation {
    condition     = var.pfe_host.ipv4_address == null || length(var.pfe_host.dns_servers) > 0
    error_message = "pfe_host.ipv4_address requires pfe_host.dns_servers — a static address means no DHCP lease and therefore no resolvers from it, and this host's cloud-init installs Docker over the network, so an empty resolv.conf reads as a first boot that never finishes rather than as a DNS fault."
  }
}

variable "redlib_release_tag" {
  description = "Redlib Docker image release tag"
  type        = string
  default     = "latest"
}
