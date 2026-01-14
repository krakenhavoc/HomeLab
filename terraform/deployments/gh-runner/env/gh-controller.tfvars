# GitHub Actions Controller Configuration
# Deploy a single controller instance for managing GitHub Actions
# IMPORTANT: This controller should be deployed first before any workers
#            and should not be self-managed, terraform apply must run
#            from a worker or local machine.

instance_count = 1

deployment_tag = "gh-controller"

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
# export TF_VAR_admin_password="your_password"
