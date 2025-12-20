variable "cloudinit-example_root-password" {
  description = "Root pass for the Example Cloud-Init VM"
  type        = string
  sensitive   = true
}

variable "k8s_controlplane" {
  description = "object containing the K8s master node configuration"
  type = object({
    node_count   = optional(number, 1)
    name_prefix  = optional(string, "k8s-controlplane")
    cpu_cores    = optional(number, 2)
    memory_bytes = optional(number, 4096)
  })
  default = {}
}

variable "k8s_worker" {
  description = "object containing the K8s worker node configuration"
  type = object({
    node_count   = optional(number, 2)
    name_prefix  = optional(string, "k8s-worker")
    cpu_cores    = optional(number, 2)
    memory_bytes = optional(number, 4096)
  })
  default = {}
}
