provider "proxmox" {
  pm_api_url      = "https://pve.labxp.io:8006/api2/json"
  pm_tls_insecure = false # By default Proxmox Virtual Environment uses self-signed certificates.
}
