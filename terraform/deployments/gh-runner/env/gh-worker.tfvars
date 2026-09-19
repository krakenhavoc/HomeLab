# GitHub Actions Runner Workers Configuration
# Deploy multiple worker instances for running GitHub Actions jobs

# Instances are named by index (gunner-0 .. gunner-N-1). Only ever increase
# this; lowering it destroys the highest-numbered runners.
instance_count = 6

# gunner-0..3 were added to cmd_and_ctrl by hand; from gunner-4 on, cloud-init
# registers them there too. Existing VMs never re-run cloud-init.
register_cmd_and_ctrl = true

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
