variable "pve" {
  description = "Object containing the ProxMox Virtual Environment details"
  type = object({
    endpoint = string
    host     = string
    username = string
  })
  default = {
    endpoint = "https://pve.labxp.io:8006"
    host     = "pve"
    username = "root@pam"
  }
}

variable "nfs_server" {
  description = "Configuration for the NFS host VM"
  type = object({
    env            = optional(string, "dev")
    name_prefix    = optional(string, "nfs")
    description    = optional(string, "NFS Server")
    tags           = optional(list(string), ["nfs"])
    cpu_cores      = optional(number, 4)
    memory_mb      = optional(number, 4096)
    disk_interface = optional(string, "virtio0")
    network_bridge = optional(string, "vmbr0")
    vlan_id        = optional(number, null)
    datastore_id   = optional(string, "local-lvm")
  })
  default = {}
}

variable "ssh_public_key" { # Passed via GitHub Vars in CI/CD
  description = "Public SSH key for accessing the NFS server"
  type        = string
  default     = ""
}
