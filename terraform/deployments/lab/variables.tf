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

variable "pwnbox" {
  description = "Object containing the Pwnbox configuration"
  type = object({
    name_prefix    = optional(string, "pwnbox")
    description    = optional(string, "CTF Pwnbox - Managed by Terraform")
    tags           = optional(list(string), ["ctf"])
    bios           = optional(string, "ovmf")
    cpu_cores      = optional(number, 4)
    memory_mb      = optional(number, 8192)
    os_disk_size   = optional(number, 50)
    disk_interface = optional(string, "virtio0")
    network_bridge = optional(string, "vmbr0")
    vlan_id        = optional(number, 200)
    admin_username = optional(string, "krkn")
  })
  default = {}
}

variable "win11" {
  description = "Object containing the Windows 11 VM configuration"
  type = object({
    name_prefix       = string
    cpu_cores         = number
    memory_mb         = number
    os_disk_size      = number
    disk_interface    = string
    disk_datastore_id = string
    network_bridge    = string
    vlan_id           = number
  })
  default = {
    name_prefix       = "win11-vm"
    cpu_cores         = 4
    memory_mb         = 8192
    os_disk_size      = 64
    disk_interface    = "virtio0"
    disk_datastore_id = "hdd_556g_thin"
    network_bridge    = "vmbr0"
    vlan_id           = 99
  }
}
