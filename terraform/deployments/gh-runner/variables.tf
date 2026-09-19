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

variable "proxmox_private_key" {
  description = "Private key for Proxmox VE API access"
  type        = string
  sensitive   = true
}

variable "instance_count" {
  description = "Number of self-hosted runners to deploy"
  type        = number
  default     = 1
  validation {
    condition     = var.instance_count > 0
    error_message = "Instance count must be greater than zero."
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

variable "deployment_tag" {
  description = "Optional override for deployment tag (gh-controller or gh-worker). Defaults to TF workspace."
  type        = string
  default     = null
}

variable "register_cmd_and_ctrl" {
  description = "Also register each new runner with krakenhavoc/cmd_and_ctrl"
  type        = bool
  default     = false
}

variable "cmd_and_ctrl_registration_token" {
  description = "Registration token for krakenhavoc/cmd_and_ctrl; required when register_cmd_and_ctrl is true"
  type        = string
  sensitive   = true
  default     = ""
  validation {
    condition     = !var.register_cmd_and_ctrl || var.cmd_and_ctrl_registration_token != ""
    error_message = "register_cmd_and_ctrl is true but cmd_and_ctrl_registration_token is empty."
  }
}
