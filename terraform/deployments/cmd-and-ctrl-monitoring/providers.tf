provider "pve" {
  endpoint = var.pve.endpoint
  insecure = false

  # Snippet uploads go over SSH.
  ssh {
    agent    = true
    username = "root"
  }
}
