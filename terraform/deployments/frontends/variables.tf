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
  })
  default = {}
}

variable "redlib_release_tag" {
  description = "Redlib Docker image release tag"
  type        = string
  default     = "latest"
}
