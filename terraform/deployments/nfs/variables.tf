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

variable "nfs_server" {
  description = "Configuration for the NFS host VM"
  type = object({
    env            = optional(string, "dev")
    name_prefix    = optional(string, "nfs")
    description    = optional(string, "NFS Server")
    tags           = optional(list(string), ["nfs"])
    bios           = optional(string, "ovmf")
    cpu_cores      = optional(number, 4)
    memory_mb      = optional(number, 4096)
    os_disk_size   = optional(number, 30)
    disk_interface = optional(string, "virtio0")
    network_bridge = optional(string, "vmbr0")
    vlan_id        = optional(number, null)
    mount_path     = optional(string, "/mnt/nfs")
    mount_volume   = optional(string, "local-lvm:vm-100-disk-0")
    datastore_id   = optional(string, "local-lvm")
  })
  default = {}
}
