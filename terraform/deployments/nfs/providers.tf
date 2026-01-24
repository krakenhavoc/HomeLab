provider "proxmox" {
  endpoint = var.pve.endpoint
  insecure = false
  username = var.pve.username

  ssh {
    agent    = true
    username = var.pve.username
    # You can also use password or private_key here
  }
}
