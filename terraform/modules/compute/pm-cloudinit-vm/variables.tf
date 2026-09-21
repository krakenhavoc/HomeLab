variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
}

variable "vm_node_name" {
  description = "Name of the Proxmox node"
  type        = string
}

variable "vm_description" {
  description = "Description of the virtual machine"
  type        = string
}

variable "vm_tags" {
  description = "Tags to apply to the virtual machine"
  type        = list(string)
  default     = []
}

variable "vm_bios" {
  description = "BIOS type (ovmf or seabios)"
  type        = string
  default     = "ovmf"

  validation {
    condition     = contains(["ovmf", "seabios"], var.vm_bios)
    error_message = "vm_bios must be either 'ovmf' or 'seabios'."
  }
}

variable "clone_vm_id" {
  description = "ID of the template VM to clone"
  type        = number
}

variable "vm_agent_enabled" {
  description = "Enable QEMU agent"
  type        = bool
  default     = true
}

variable "vm_cpu_cores" {
  description = "Number of CPU cores"
  type        = number
}

variable "vm_memory_mb" {
  description = "Memory in MB"
  type        = number
}

variable "vm_disk_datastore_id" {
  description = "Datastore ID for the disk"
  type        = string
}

variable "vm_disk_interface" {
  description = "Disk interface type (virtio0, scsi0, etc.)"
  type        = string
  default     = "virtio0"
}

variable "vm_disk_size" {
  description = "Disk size in GB"
  type        = number
}

variable "vm_cloudinit_datastore_id" {
  description = "Datastore ID for cloud-init"
  type        = string
}

variable "vm_cloudinit_user_data_file_id" {
  description = "File ID of the cloud-init user data"
  type        = string
}

variable "vm_network_bridge" {
  description = "Network bridge for the VM"
  type        = string
}

variable "vm_vlan_id" {
  description = "VLAN ID for the network device"
  type        = number
  default     = null
}

# -----------------------------------------------------------------------------
# Static addressing (all optional, all off by default)
# -----------------------------------------------------------------------------
# Every variable below defaults to null or empty, and every one of those
# defaults renders EXACTLY the configuration this module rendered before they
# existed: ip_config.ipv4.address = "dhcp", no gateway attribute, no dns block,
# no mac_address attribute. That is a hard requirement, not politeness. This
# module is consumed by openclaw, openclaw-2 and pwnbox (lab), redlib
# (frontends) and plex, all pinned to a released ref. The moment a default here
# renders differently, every one of those VMs shows a diff on the
# `initialization` block -- and a diff on `initialization` is not cosmetic: it
# rewrites the cloud-init drive and the provider reboots the guest to apply it.
# Do not give any of these a non-null default.
#
# These exist because lab VMs had no stable addressing at all: openclaw-2 came
# back on 192.168.200.37 after a rebuild that had put it on .36, because DHCP
# is the only thing that ever decided. Anything that referenced the old address
# -- an SSH config, a firewall rule, a note -- silently pointed at nothing.

variable "vm_ipv4_address" {
  description = <<-EOT
    Static IPv4 address in CIDR form, e.g. "192.168.200.40/24". Null (the
    default) leaves the guest on DHCP.

    The prefix length is not decoration. Proxmox copies this string more or
    less verbatim into the cloud-init ipconfig0 line, and a bare address with
    no prefix produces network config the guest cannot render -- which means a
    VM that boots with no address, no SSH, and nothing to look at but the
    Proxmox console.

    This is cloud-init data, so it is consumed on FIRST BOOT. Changing it on a
    live VM rewrites the cloud-init drive and the provider restarts the guest
    to pick it up; it does not reconfigure a running guest in place, and on a
    guest whose cloud-init has already run once it may not take effect at all
    without a rebuild. Pick the address before the VM exists where you can.

    Rejected alternative: defaulting this to "dhcp" and passing it straight
    through. It reads better at the resource but destroys the one signal
    everything else keys on -- null/not-null is how this module knows whether
    the host is statically addressed, and it is what the gateway validation
    below and the operator-facing docs both rely on.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.vm_ipv4_address == null || can(cidrnetmask(var.vm_ipv4_address))
    error_message = "vm_ipv4_address must be an IPv4 address carrying a prefix length, e.g. \"192.168.200.40/24\" — a bare address or an IPv6 address writes an ipconfig0 line the guest cannot render, and the VM boots with no network and no way in except the Proxmox console."
  }
}

variable "vm_ipv4_gateway" {
  description = <<-EOT
    Default gateway for the static address, e.g. "192.168.200.1". Null (the
    default) writes no gateway attribute at all.

    Only meaningful alongside vm_ipv4_address -- a DHCP lease carries its own
    gateway, and a gateway declared next to "dhcp" is thrown away without
    complaint. The validation below turns that silent no-op into a plan-time
    error.

    A static address with a null gateway is legal and occasionally what you
    want: the guest is reachable on its own subnet and has no route off it.
    Every lab VM so far wants a gateway, so treat a missing one as a mistake
    unless you meant it.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.vm_ipv4_gateway == null || var.vm_ipv4_address != null
    error_message = "vm_ipv4_gateway requires vm_ipv4_address — on DHCP the gateway comes from the lease and a declared one is discarded, so the VM would come up on a DHCP address while the config claimed it had a fixed route, and nothing would report the discrepancy."
  }

  validation {
    # Appending /32 turns a bare address into something cidrnetmask can parse;
    # a value that already carries a prefix (the usual paste-the-CIDR-twice
    # mistake) becomes "a.b.c.d/24/32" and fails, which is the point.
    condition     = var.vm_ipv4_gateway == null || can(cidrnetmask("${var.vm_ipv4_gateway}/32"))
    error_message = "vm_ipv4_gateway must be a bare IPv4 address with no prefix length, e.g. \"192.168.200.1\" — Proxmox rejects an ipconfig0 line whose gw= carries a netmask, and the VM fails to start rather than starting misconfigured."
  }
}

variable "vm_dns_servers" {
  description = <<-EOT
    Nameservers written into the cloud-init drive. Empty (the default) omits
    the dns block entirely and leaves the guest with whatever DHCP handed it.

    Set this whenever vm_ipv4_address is set. A static address takes the guest
    off DHCP completely, and it loses the lease's resolvers along with the
    lease -- a statically addressed VM with no dns entry boots with an empty
    resolv.conf. That does not present as a DNS fault; it presents as a
    first boot that hangs, because every apt/curl/git step in the cloud-init
    template is waiting on a name that will never resolve.

    Deliberately not validated against vm_ipv4_address. A guest can legitimately
    carry its resolvers from an image or a later config-management pass, and an
    error here would block that for no gain.
  EOT
  type        = list(string)
  default     = []
}

variable "vm_dns_domain" {
  description = <<-EOT
    DNS search domain for the guest, e.g. "labxp.io". Null (the default) omits
    the attribute, which leaves short-name resolution to whatever the guest
    already does.

    Setting this alone (with no vm_dns_servers) is allowed and does render a
    dns block, because a search domain on top of DHCP-supplied resolvers is a
    coherent thing to ask for.
  EOT
  type        = string
  default     = null
}

variable "vm_mac_address" {
  description = <<-EOT
    Pinned MAC address for the VM's network device, e.g. "BC:24:11:00:02:40".
    Null (the default) lets Proxmox generate one at create time; the generated
    value is recorded in state and survives everything except a rebuild.

    That last clause is the whole reason this exists: a rebuild draws a new MAC,
    which loses any DHCP reservation and any firewall rule keyed on the old one.
    Pin this when something off-box keys on the MAC and cannot be re-pointed.

    BC:24:11 is Proxmox's own OUI, so addresses under it are already understood
    to be virtual and will not collide with real hardware on the segment.

    Think twice about setting this AND vm_ipv4_address. A DHCP reservation
    keyed on a pinned MAC and a static address in cloud-init are two sources of
    truth for the same fact; when they disagree the guest wins, the reservation
    sits unused, and the DHCP server happily leases the reserved address to
    nobody while someone debugs the wrong end of it. Pick one.
  EOT
  type        = string
  default     = null

  validation {
    condition     = var.vm_mac_address == null || can(regex("^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$", var.vm_mac_address))
    error_message = "vm_mac_address must be six colon-separated hex octets, e.g. \"BC:24:11:00:02:40\" — Proxmox rejects any other form at apply time, after the plan has already been approved."
  }
}

# -----------------------------------------------------------------------------
# Power state
# -----------------------------------------------------------------------------
# Both default to true, which is what the provider already assumes when these
# attributes are not written at all. So adding them renders byte-for-byte the
# configuration this module rendered before they existed, and openclaw-2,
# pwnbox, redlib and plex see no diff. Same hard requirement as the static
# addressing block above: do not give either of these a false default.
#
# WHY THIS EXISTS: the provider's defaults are not neutral. Every VM this
# module manages is declared running and declared to autostart whether or not
# anyone said so, so a host that is deliberately powered off has no way to say
# so and shows up in every plan as `started = false -> true`. openclaw is
# exactly that host -- it is off on purpose, and the pending lab plan wants to
# start it and enable autostart. Leaving the attribute unset is not "don't
# care", it is "running".

variable "vm_started" {
  description = <<-EOT
    Whether the VM should be running. True (the default) matches the
    provider's own default, so leaving it alone changes nothing.

    Set false for a host that is deliberately powered off. Without it there is
    no way to express that, and Terraform keeps proposing to start the guest
    on every plan until someone applies one.

    This is a declared power state, not a one-off action. Terraform will start
    a stopped guest to satisfy true, and stop a running one to satisfy false,
    on whatever apply comes next -- including an apply that was really about
    something else entirely.
  EOT
  type        = bool
  default     = true
}

variable "vm_on_boot" {
  description = <<-EOT
    Whether the VM autostarts when the Proxmox node boots. True (the default)
    matches the provider's own default.

    Independent of vm_started despite reading like a pair: a guest can be
    running now but not autostart, or be off now and come back with the node.
    The combination worth being deliberate about is started=false with
    on_boot=true -- a host that is off today and returns by itself after the
    next node reboot, which is rarely what anyone means by "powered off".
  EOT
  type        = bool
  default     = true
}
