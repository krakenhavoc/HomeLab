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

variable "pfe_host" {
  description = "Configuration for the private frontends / gateway host"
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
    # on BOTH hosts rather than as an obvious failure.
    ipv4_address = optional(string, null)
    ipv4_gateway = optional(string, null)

    # Required whenever ipv4_address is set, and enforced below. A static
    # address means no DHCP lease and therefore no resolvers from it, and
    # this host's first boot clones a git repository and pulls four container
    # images. An empty resolv.conf does not read as a DNS fault; it reads as
    # a first boot that never finishes.
    dns_servers = optional(list(string), [])
    dns_domain  = optional(string, null)
  })
  default = {}

  # Duplicated from the module (pm-cloudinit-vm) deliberately: these fail
  # earlier and name the variable the operator actually edited rather than a
  # module input two hops away.
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
    error_message = "pfe_host.ipv4_address requires pfe_host.dns_servers — a static address means no DHCP lease and therefore no resolvers from it, and this host's cloud-init clones a repository and pulls container images, so an empty resolv.conf reads as a first boot that never finishes rather than as a DNS fault."
  }

  # The gateway's whole premise is that one address is where every internal
  # name points. A DHCP lease cannot be that, so this host specifically must
  # not be left on one -- unlike the module, where DHCP remains a valid
  # default for hosts nothing else references.
  validation {
    condition     = var.pfe_host.ipv4_address != null
    error_message = "pfe_host.ipv4_address is required — this host is the lab gateway and both Pi-holes point every internal name at its address, so it cannot be a DHCP lease that a rebuild is free to change."
  }
}

variable "cloudflare_api_token" {
  description = <<-EOT
    Cloudflare API token used by Caddy on this host for the ACME DNS-01
    challenge. Two permissions on the labxp.io zone:

      Zone : DNS  : Edit
      Zone : Zone : Read

    Zone:Read is not optional padding -- caddy-dns/cloudflare resolves the
    zone ID from its name with GET /zones?name=labxp.io before it can write
    anything. Without it the failure arrives at certificate issuance as an
    empty zone lookup rather than as a permission error.

    DNS-01 is what lets this host hold genuine Let's Encrypt certificates for
    internal names while the lab accepts no inbound connection from the
    internet: control of a name is proved by writing a TXT record, not by
    answering a request.

    CHECK CLIENT IP ADDRESS FILTERING FIRST if issuance starts failing with
    401 code 10000. The lab pipeline lost a day to exactly that on
    2026-09-21: a valid, correctly scoped, unexpired token whose IP filter no
    longer matched the caller. Calls from this host carry the lab's WAN
    address, and that address changes on its own. 401/10000 is
    indistinguishable from a dead token; 403/10000 is a missing permission.

    Supplied as the existing repo-wide CLOUDFLARE_API_TOKEN, which is broader
    than this needs -- it also carries tunnel and R2 write, so filesystem
    access on this host grants those too. A token scoped to just the two
    permissions above would be tighter; swapping it is a one-line change to
    the GitHub environment secret and no change here.
  EOT
  type        = string
  sensitive   = true

  # The shared terraform-ci workflow sets TF_VAR_cloudflare_api_token
  # unconditionally, so a deployment that forgets to pass the secret through
  # gets an empty string rather than a missing-variable error. Without this
  # check that empty string reaches the host, Caddy starts happily, and the
  # first symptom is certificates that never issue -- minutes of ACME retries
  # pointing at DNS rather than at a workflow that is missing one line.
  validation {
    condition     = length(var.cloudflare_api_token) > 0
    error_message = "cloudflare_api_token is empty — frontends-deploy.yaml must pass secrets.CLOUDFLARE_API_TOKEN through to terraform-ci/terraform-cd. An empty token is written to the host verbatim and only shows up later as ACME failures."
  }
}
