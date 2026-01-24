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

variable "clone_vm_id" {
  description = "ID of the template VM to clone"
  type        = number
}

variable "vm_disk_datastore_id" {
  description = "Datastore ID for the VM disk"
  type        = string
}

variable "vm_cloudinit_datastore_id" {
  description = "Datastore ID for cloud-init snippets"
  type        = string
}

variable "plex_host" {
  description = "Configuration for the Plex host VM"
  type = object({
    env            = optional(string, "dev")
    name_prefix    = optional(string, "plex-hibiscus")
    description    = optional(string, "Plex Media Server")
    tags           = optional(list(string), ["plex"])
    bios           = optional(string, "ovmf")
    cpu_cores      = optional(number, 4)
    memory_mb      = optional(number, 4096)
    os_disk_size   = optional(number, 30)
    disk_interface = optional(string, "virtio0")
    network_bridge = optional(string, "vmbr0")
    vlan_id        = optional(number, null)
  })
  default = {}
}

variable "plex_release_tag" {
  description = "Plex Docker image release tag"
  type        = string
  default     = "latest"
}

variable "nfs_server_ip" {
  description = "IP of the NFS server to mount shares from"
  type        = string
  default     = ""
}

variable "nfs_server_path" {
  description = "Path on the NFS server to mount"
  type        = string
  default     = "/export/nfs"
}
