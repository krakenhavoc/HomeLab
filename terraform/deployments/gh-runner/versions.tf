terraform {
  required_version = "~> 1.14.3"

  required_providers {
    # proxmox = {
    #   source  = "Telmate/proxmox"
    #   version = "3.0.2-rc07"
    # }

    pve = {
      source  = "bpg/proxmox"
      version = "0.93.0"
    }

    null = {
      source  = "hashicorp/null"
      version = "3.2.4"
    }
  }
}
