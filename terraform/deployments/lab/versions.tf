terraform {
  required_version = "~> 1.14.3"

  required_providers {
    proxmox = {
      source  = "bpg/proxmox"
      version = "0.93.0"
    }
  }
}
