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

variable "netcrawl_host" {
  description = "Configuration for the NetCrawl web host (nginx serving the Godot web build)"
  type = object({
    env            = optional(string, "dev")
    name_prefix    = optional(string, "netcrawl")
    description    = optional(string, "NetCrawl web build (nginx, static)")
    tags           = optional(list(string), ["apps"])
    bios           = optional(string, "ovmf")
    cpu_cores      = optional(number, 1)
    memory_mb      = optional(number, 1024)
    os_disk_size   = optional(number, 20)
    disk_interface = optional(string, "virtio0")
    network_bridge = optional(string, "vmbr0")
    vlan_id        = optional(number, 201)

    # Static DHCP lease on the firewall is keyed on this.
    mac_address = optional(string, null)
  })
  default = {}

  validation {
    condition     = var.netcrawl_host.mac_address != null && can(regex("^([0-9A-Fa-f]{2}:){5}[0-9A-Fa-f]{2}$", var.netcrawl_host.mac_address))
    error_message = "netcrawl_host.mac_address is required, e.g. \"BC:24:11:00:02:70\" — the firewall's static lease is keyed on it."
  }
}
