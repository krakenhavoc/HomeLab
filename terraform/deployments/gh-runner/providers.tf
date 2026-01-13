provider "proxmox" {
  pm_api_url      = "https://pve.labxp.io:8006/api2/json"
  pm_tls_insecure = false # By default Proxmox Virtual Environment uses self-signed certificates.
}

provider "null" {
  # Configuration options
}

provider "pve" {
  endpoint = var.pve.endpoint
  insecure = false

  ssh {
    agent    = true
    username = "root"
    # You can also use password or private_key here
  }
}
