provider "proxmox" {
  pm_api_url      = "https://pve.cloudwalker.it:8006/api2/json"
  pm_tls_insecure = true # By default Proxmox Virtual Environment uses self-signed certificates.
}
