terraform {
  required_version = "~> 1.14.3"

  required_providers {
    pve = {
      source  = "bpg/proxmox"
      version = ">= 0.93.0, < 1.0"
    }
  }
}
