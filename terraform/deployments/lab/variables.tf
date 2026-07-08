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

variable "vm_disk_datastore_id" {
  description = "Datastore ID for the VM disk"
  type        = string
  default     = "ssd_1641G_thin"
}

variable "vm_cloudinit_datastore_id" {
  description = "Datastore ID for cloud-init snippets"
  type        = string
  default     = "ssd_1641G_thin"
}

variable "openclaw" {
  description = "Object containing the OpenClaw configuration"
  type = object({
    name_prefix    = optional(string, "openclaw")
    description    = optional(string, "OpenClaw Gateway - Managed by Terraform")
    tags           = optional(list(string), ["openclaw"])
    bios           = optional(string, "ovmf")
    cpu_cores      = optional(number, 4)
    memory_mb      = optional(number, 16384)
    os_disk_size   = optional(number, 50)
    disk_interface = optional(string, "virtio0")
    network_bridge = optional(string, "vmbr0")
    vlan_id        = optional(number, 200)
    admin_username = optional(string, "krkn")
  })
  default = {}
}

variable "pwnbox" {
  description = "Object containing the Pwnbox configuration"
  type = object({
    name_prefix    = optional(string, "pwnbox")
    description    = optional(string, "CTF Pwnbox - Managed by Terraform")
    tags           = optional(list(string), ["ctf"])
    bios           = optional(string, "ovmf")
    cpu_cores      = optional(number, 4)
    memory_mb      = optional(number, 16384)
    os_disk_size   = optional(number, 50)
    disk_interface = optional(string, "virtio0")
    network_bridge = optional(string, "vmbr0")
    vlan_id        = optional(number, 200)
    admin_username = optional(string, "krkn")
  })
  default = {}
}

variable "cmd_and_ctrl" {
  description = "Object containing the cmd_and_ctrl game server configuration"
  type = object({
    name_prefix    = optional(string, "cmd-and-ctrl")
    description    = optional(string, "cmd_and_ctrl game server - Managed by Terraform")
    tags           = optional(list(string), ["cmd-and-ctrl", "gameserver"])
    bios           = optional(string, "ovmf")
    cpu_cores      = optional(number, 2)
    memory_mb      = optional(number, 4096)
    os_disk_size   = optional(number, 40)
    data_disk_size = optional(number, 20)
    network_bridge = optional(string, "vmbr0")
    vlan_id        = optional(number, 200)
    admin_username = optional(string, "krkn")
    fqdn           = optional(string, "cmd.labxp.io")
  })
  default = {}
}

variable "cmd_and_ctrl_admin_token" {
  description = "Admin token for cmd_and_ctrl server (CMDCTRL_ADMIN_TOKEN). 16+ chars."
  type        = string
  sensitive   = true
}

variable "cmd_and_ctrl_tunnel_token" {
  description = "Cloudflare Tunnel token for cmd.labxp.io. Generated in Cloudflare Zero Trust dashboard."
  type        = string
  sensitive   = true
}

variable "cmd_and_ctrl_github_token" {
  description = <<-EOT
    Fine-grained GitHub PAT for the in-app bug-report button (cmd_and_ctrl
    ADR 0017): Issues:write on krakenhavoc/cmd_and_ctrl only. Seeds the
    first-boot env file in the cloud-init template so a rebuilt VM starts
    with bug reporting live. Flows in as TF_VAR_cmd_and_ctrl_github_token
    from the CMD_AND_CTRL_GITHUB_TOKEN environment secret (lab), same as
    the admin/tunnel tokens. The steady-state copy on the host is synced
    by the cmd_and_ctrl repo's CD pipeline from that repo's own
    CMDCTRL_GITHUB_TOKEN Actions secret (managed by hand — deliberately
    not Terraform; one secret didn't justify a github-provider
    credential). Empty string (the default) writes no env line.
  EOT
  type        = string
  sensitive   = true
  default     = ""
}

variable "windows11" {
  description = "Object containing the Windows 11 VM configuration"
  type = object({
    name_prefix    = optional(string, "win11")
    description    = optional(string, "Windows 11 - Managed by Terraform")
    tags           = optional(list(string), ["windows"])
    cpu_cores      = optional(number, 4)
    memory_mb      = optional(number, 8192)
    os_disk_size   = optional(number, 64)
    network_bridge = optional(string, "vmbr0")
    vlan_id        = optional(number, null)
  })
  default = {}
}
