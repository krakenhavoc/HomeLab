# GitHub Actions Runner Workers Configuration
# Deploy multiple worker instances for running GitHub Actions jobs

deployment_tag = "gh-worker"

gh_runner = {
  name_prefix    = "gunner"
  cpu_cores      = 2
  memory_mb      = 4096
  template       = "noble-template"
  os_disk_size   = 50
  network_bridge = "vmbr0"
  admin_username = "gh-runner"
}

# Sensitive variables must be set via environment or CLI:
# export TF_VAR_gh_registration_token="your_token"
