variable "vm_name" {
  description = "(Required) Name for VM | Changing this forces resource to be recreated"
  type        = string
}

variable "pve_node" {
  description = "(Optional) Proxmox Virtual Environment Node to deploy to | Default: pve"
  type        = string
  default     = "pve"
}

variable "enable_qemu_guest_agent" {
  description = "(Optional) Enable the QEMU guest agent? | Default: 1 (true)"
  type        = number
  default     = 1
}

variable "memory_mb" {
  description = "(Optional) VM amount of RAM in megabytes | Default: 2048"
  type        = number
  default     = 2048
}

variable "clone_name" {
  description = "(Optional) Name of the template to be cloned | Default: ubuntu-noble-template"
  type        = string
  default     = "ubuntu-noble-template"
}

variable "vm_state" {
  description = "(Optional) VM State on creation | Default: running"
  type        = string
  default     = "running"
}

variable "cpu_cores" {
  description = "(Optional) Number of VM CPU cores | Default: 2"
  type        = number
  default     = 2
}

variable "ci_user_data" {
  description = "(Optional) Path to cloud init startup config | Default: vendor=local:snippets/ubuntu.yml"
  type        = string
  default     = "vendor=local:snippets/ubuntu.yml"
}

variable "dns_nameservers" {
  description = "(Optional) Space delimited list of DNS servers | Default: 1.1.1.1 8.8.8.8"
  type        = string
  default     = "1.1.1.1 8.8.8.8"
}

variable "username" {
  description = "(Optional) VM username (only valid during creation) | Default: root"
  type        = string
  default     = "root"
}

variable "cloudinit-example_root-password" {
  description = "(Optional) VM password (only valid during creation) | Default: <pulled from repo secret and overrides any value here>" #Future release should add secure generation and/or user input
  type        = string
  default     = ""
}

variable "os_disk_size" {
  description = "(Optional) OS Disk size | Default: 15G"
  type        = string
  default     = "15G"
}

variable "network_bridge" {
  description = "(Optional) Host network adapter to use | Default: vmbr0 (same as host)"
  type        = string
  default     = "vmbr0"
}
