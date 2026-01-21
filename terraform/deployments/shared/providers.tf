provider "proxmox" {
  endpoint = var.pve.endpoint
  insecure = false

  ssh {
    agent    = true
    username = "root"
    # You can also use password or private_key here
  }
}

provider "external" {
}
