# variable "cloudinit-example_root-password" {
#   description = "Root pass for the Example Cloud-Init VM"
#   type        = string
#   sensitive   = true
# }

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

variable "instance_count" {
  description = "Number of self-hosted runners to deploy"
  type        = number
  default     = 1
  validation {
    condition     = var.instance_count > 1
    error_message = "Instance count must be greater than one."
  }
}

variable "gh_runner" {
  description = "Object containing the GitHub Runner configuration"
  type = object({
    name_prefix    = optional(string, "gunner")
    cpu_cores      = optional(number, 2)
    memory_mb      = optional(number, 4096)
    template       = optional(string, "noble-template")
    os_disk_size   = optional(number, 50)
    network_bridge = optional(string, "vmbr0")
    admin_username = optional(string, "krkn")
  })
  default = {}
}

variable "gh_registration_token" {
  type      = string
  sensitive = true
}

variable "admin_password" {
  description = "Password for the admin user"
  type        = string
  sensitive   = true
}
