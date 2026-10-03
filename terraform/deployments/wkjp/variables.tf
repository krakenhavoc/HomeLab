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

variable "wkjp_host" {
  description = "Configuration for the wkjp host (nginx + VOICEVOX)"
  type = object({
    env            = optional(string, "prd")
    name_prefix    = optional(string, "wkjp")
    description    = optional(string, "WaniKani listening practice (nginx, VOICEVOX)")
    tags           = optional(list(string), ["apps"])
    bios           = optional(string, "ovmf")
    cpu_cores      = optional(number, 2)
    memory_mb      = optional(number, 4096)
    os_disk_size   = optional(number, 30)
    disk_interface = optional(string, "virtio0")
    network_bridge = optional(string, "vmbr0")
    vlan_id        = optional(number, 201)

    # Static DHCP lease on the firewall is keyed on this.
    mac_address = optional(string, null)
  })
  default = {}

  validation {
    condition     = var.wkjp_host.mac_address != null && can(regex("^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$", var.wkjp_host.mac_address))
    error_message = "wkjp_host.mac_address is required, e.g. \"BC:24:11:00:02:60\" — the firewall's static lease is keyed on it."
  }
}
