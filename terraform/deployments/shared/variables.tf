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

variable "win11_iso_url" {
  description = "URL to download the latest Windows 11 ISO"
  type        = string
}

variable "datastore_id" {
  description = "Datastore ID for the VM disk"
  type        = string
}
