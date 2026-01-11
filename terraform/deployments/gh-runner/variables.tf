variable "cloudinit-example_root-password" {
  description = "Root pass for the Example Cloud-Init VM"
  type        = string
  sensitive   = true
}

variable "gh_runner" {
  description = "object containing the GitHub Runner configuration"
  type = object({
    node_count     = optional(number, 1)
    name_prefix    = optional(string, "gunner")
    cpu_cores      = optional(number, 2)
    memory_mb      = optional(number, 4096)
    template       = optional(string, "noble-template")
    os_disk_size   = optional(string, "50G")
    network_bridge = optional(string, "vmbr0")
  })
  default = {}
}
