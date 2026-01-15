variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
}

variable "vm_node_name" {
  description = "Name of the Proxmox node"
  type        = string
}

variable "vm_description" {
  description = "Description of the virtual machine"
  type        = string
}

variable "vm_tags" {
  description = "Tags to apply to the virtual machine"
  type        = list(string)
  default     = []
}

variable "vm_bios" {
  description = "BIOS type (ovmf or seabios)"
  type        = string
  default     = "ovmf"

  validation {
    condition     = contains(["ovmf", "seabios"], var.vm_bios)
    error_message = "vm_bios must be either 'ovmf' or 'seabios'."
  }
}

variable "clone_vm_id" {
  description = "ID of the template VM to clone"
  type        = number
}

variable "vm_agent_enabled" {
  description = "Enable QEMU agent"
  type        = bool
  default     = true
}

variable "vm_cpu_cores" {
  description = "Number of CPU cores"
  type        = number
}

variable "vm_memory_mb" {
  description = "Memory in MB"
  type        = number
}

variable "vm_disk_datastore_id" {
  description = "Datastore ID for the disk"
  type        = string
}

variable "vm_disk_interface" {
  description = "Disk interface type (virtio0, scsi0, etc.)"
  type        = string
  default     = "virtio0"
}

variable "vm_disk_size" {
  description = "Disk size in GB"
  type        = number
}

variable "vm_cloudinit_datastore_id" {
  description = "Datastore ID for cloud-init"
  type        = string
}

variable "vm_cloudinit_user_data_file_id" {
  description = "File ID of the cloud-init user data"
  type        = string
}

variable "vm_network_bridge" {
  description = "Network bridge for the VM"
  type        = string
}

variable "vm_vlan_id" {
  description = "VLAN ID for the network device"
  type        = number
  default     = null
}
