variable "cloudinit-example_root-password" {
  description = "Root pass for the Example Cloud-Init VM"
  type        = string
  sensitive   = true
}

variable "plex_host" {
  description = "object containing the plex host configuration"
  type = object({
    name_prefix    = optional(string, "plex-hibiscus")
    cpu_cores      = optional(number, 4)
    memory_mb      = optional(number, 4096)
    os_disk_size   = optional(string, "30G")
    network_bridge = optional(string, "vmbr201")
  })
  default = {}
}
