# GitHub Actions Self-Hosted Runner Deployment

Terraform deployment for self-hosted GitHub Actions runner on Proxmox.

## 📋 Overview

This deployment creates a dedicated VM for running GitHub Actions workflows with:
- **Ubuntu 22.04 LTS** - Base operating system
- **GitHub Actions Runner** - Self-hosted runner agent
- **Docker** - Container support for workflows
- **Cloud-init** - Automated provisioning and registration
- **Persistent configuration** - Runner survives VM restarts

## 🏗️ Infrastructure Components

### Runner VM
- **CPU**: 4 cores (for parallel jobs)
- **Memory**: 8192 MB (8 GB)
- **Disk**: 100 GB (OS, Docker images, build cache)
- **IP**: DHCP or static (configurable)
- **Network**: Management or Server VLAN
- **Labels**: Custom labels for job targeting

## 📁 Directory Structure

```
gh-runner/
├── main.tf              # Main Terraform configuration
├── variables.tf         # Input variable definitions
├── outputs.tf           # Output values (optional)
├── providers.tf         # Provider configuration
├── versions.tf          # Version constraints
├── backend.tf           # State backend configuration
├── locals.tf            # Local values
├── data.tf              # Data sources
├── env/                 # Environment-specific configurations
└── README.md            # This file
```

## 🚀 Quick Start

### Prerequisites

1. **GitHub Repository** or Organization with admin access
2. **GitHub Personal Access Token (PAT)** with `repo` and `admin:org` scopes
3. **Proxmox VE** with API access
4. **Ubuntu 22.04 cloud image** template
5. **Terraform** >= 1.0
6. **SSH keys** generated

### Step 1: Create GitHub PAT

1. Go to GitHub Settings > Developer settings > Personal access tokens
2. Generate new token (classic)
3. Select scopes:
   - `repo` (Full control of private repositories)
   - `admin:org` (if organization runner)
4. Save token securely

### Step 2: Configure Environment

```bash
# .env (don't commit)
export PM_API_URL="https://proxmox.homelab.local:8006/api2/json"
export PM_API_TOKEN_ID="terraform@pam!terraform"
export PM_API_TOKEN_SECRET="your-secret-here"
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
export TF_VAR_github_token="ghp_your_github_token"
export TF_VAR_github_repo="owner/repo"  # or organization name
```

Load environment:
```bash
source .env
```

### Step 3: Configure Variables

Create `terraform.tfvars`:
```hcl
# VM Configuration
vm_name = "gh-runner-01"
cpu_cores = 4
memory_mb = 8192
disk_size_gb = 100

# GitHub Configuration
github_token = "ghp_xxxxxxxxxxxxx"  # Use env var instead
github_repo = "owner/repository"    # or org name for org runner
runner_name = "homelab-runner-01"
runner_labels = ["self-hosted", "linux", "x64", "homelab"]

# Network Configuration (optional)
use_dhcp = true
# Or static:
# vm_ip = "192.168.1.120"
# gateway = "192.168.1.1"
# dns_server = "192.168.1.2"
```

### Step 4: Deploy

```bash
# Initialize
terraform init

# Plan
terraform plan -out=runner.tfplan

# Apply
terraform apply runner.tfplan
```

Deployment takes 5-10 minutes.

### Step 5: Verify Runner

1. Go to GitHub repository or organization Settings
2. Navigate to Actions > Runners
3. Verify runner appears as "Idle" and "Online"

## 🔧 Configuration

### Variables

#### Required Variables
```hcl
pm_api_url              # Proxmox API URL
pm_api_token_id         # Proxmox API token ID
pm_api_token_secret     # Proxmox API token secret
ssh_public_key          # SSH public key
github_token            # GitHub PAT for runner registration
github_repo             # Repository or org name
```

#### Optional Variables
```hcl
proxmox_node = "pve"                    # Proxmox node
template_name = "ubuntu-2204-template"  # Template
vm_name = "gh-runner-01"                # VM name
cpu_cores = 4                           # CPU cores
memory_mb = 8192                        # Memory in MB
disk_size_gb = 100                      # Disk size
runner_name = "homelab-runner"          # Runner display name
runner_labels = ["self-hosted"]         # Custom labels
runner_group = "Default"                # Runner group (org only)
use_dhcp = true                         # DHCP vs static IP
```

### Runner Labels

Labels allow you to target specific runners in workflows:

```yaml
# .github/workflows/example.yml
jobs:
  build:
    runs-on: [self-hosted, linux, homelab]
    steps:
      - uses: actions/checkout@v3
      - run: echo "Running on homelab runner!"
```

Common label strategies:
- **Environment**: `dev`, `staging`, `prod`
- **Capabilities**: `docker`, `gpu`, `large-disk`
- **Location**: `homelab`, `datacenter`, `cloud`

### Cloud-init Configuration

The cloud-init script (`../../scripts/deployment/cloud-init/snippets/setup-gh-runner.yaml`) handles:
- System updates
- Docker installation
- GitHub Runner download and installation
- Runner registration with GitHub
- Service configuration
- Automatic start on boot

## 📦 Post-Deployment

### Verify Runner Status

```bash
# SSH to runner VM
ssh root@<runner-ip>

# Check runner service
systemctl status actions.runner.*

# View runner logs
journalctl -u actions.runner.* -f
```

### Test Runner

Create a test workflow in your repository:

```yaml
# .github/workflows/test-runner.yml
name: Test Self-Hosted Runner

on:
  workflow_dispatch:

jobs:
  test:
    runs-on: [self-hosted, linux]
    steps:
      - name: Echo runner info
        run: |
          echo "Runner: ${{ runner.name }}"
          echo "OS: ${{ runner.os }}"
          echo "Arch: ${{ runner.arch }}"
          
      - name: Check Docker
        run: docker --version
        
      - name: System info
        run: |
          uname -a
          free -h
          df -h
```

### Configure Runner Settings

On the runner VM, edit configuration:

```bash
# Navigate to runner directory
cd /actions-runner

# Runner is configured at:
# .credentials
# .runner (runner registration)
# .path (PATH configuration)

# Runner service:
systemctl status actions.runner.*
```

## 🔄 Maintenance

### Update Runner

```bash
# SSH to runner
ssh root@<runner-ip>

# Stop runner service
systemctl stop actions.runner.*

# Download latest runner
cd /actions-runner
RUNNER_VERSION=$(curl -s https://api.github.com/repos/actions/runner/releases/latest | grep tag_name | cut -d '"' -f 4 | cut -c 2-)
curl -o actions-runner-linux-x64.tar.gz -L https://github.com/actions/runner/releases/download/v${RUNNER_VERSION}/actions-runner-linux-x64-${RUNNER_VERSION}.tar.gz

# Extract
tar xzf ./actions-runner-linux-x64.tar.gz

# Start runner service
systemctl start actions.runner.*
```

### Update System Packages

```bash
# SSH to runner
ssh root@<runner-ip>

# Update system
apt update && apt upgrade -y

# Update Docker
apt install --only-upgrade docker-ce docker-ce-cli containerd.io
```

### Deregister Runner

```bash
# SSH to runner
ssh root@<runner-ip>

# Stop service
systemctl stop actions.runner.*

# Remove runner
cd /actions-runner
./config.sh remove --token <removal-token>

# Get removal token from GitHub:
# Repository Settings > Actions > Runners > Remove
```

### Scale Runners

To add more runners, increment the count or deploy additional VMs:

```hcl
# Deploy multiple runners
count = 3
vm_name = "gh-runner-${count.index + 1}"
```

Or use Terraform workspaces:
```bash
terraform workspace new runner-02
terraform apply
```

## 🐛 Troubleshooting

### Runner Not Appearing in GitHub

```bash
# Check runner service
systemctl status actions.runner.*

# Check runner logs
journalctl -u actions.runner.* -f

# Check registration
cd /actions-runner
cat .runner

# Verify network connectivity
curl -I https://github.com
```

### Runner Offline

```bash
# Check service status
systemctl status actions.runner.*

# Restart service
systemctl restart actions.runner.*

# Check logs for errors
journalctl -u actions.runner.* --since "10 minutes ago"
```

### Workflow Fails

```bash
# Check Docker status (if using containers)
systemctl status docker
docker ps

# Check disk space
df -h

# Check logs
journalctl -u actions.runner.* -f
tail -f /actions-runner/_diag/Runner_*.log
```

### Permission Issues

```bash
# Check runner user
ps aux | grep Runner.Listener

# Fix Docker permissions
usermod -aG docker runner
systemctl restart actions.runner.*

# Check file permissions
ls -la /actions-runner
```

## 🔐 Security

### Best Practices

1. **Token Management**
   - Use short-lived tokens
   - Store tokens securely (env vars, secrets manager)
   - Rotate tokens regularly
   - Never commit tokens to git

2. **Runner Isolation**
   - Use dedicated VMs per project
   - Implement network segmentation
   - Restrict outbound network access
   - Regular security updates

3. **Workflow Security**
   - Review workflow definitions
   - Limit runner access to specific repositories
   - Use runner groups for organization
   - Monitor runner activity

4. **VM Security**
   - SSH key authentication only
   - Firewall rules enabled
   - Regular OS updates
   - Audit logs enabled

### Secure Token Storage

Use environment variables or secrets manager:

```bash
# Use environment variable
export TF_VAR_github_token=$(cat ~/.github-token)

# Or use Vault
export TF_VAR_github_token=$(vault kv get -field=token secret/github/runner)
```

## 📊 Monitoring

### Runner Metrics

```bash
# Active jobs
cd /actions-runner
cat _diag/Runner_*.log | grep "Running job"

# Resource usage
htop
docker stats

# Disk usage
du -sh /actions-runner/_work/*
```

### Integration with Monitoring Stack

Consider adding:
- Prometheus node exporter
- Custom metrics exporter for runner stats
- Grafana dashboard for runner monitoring
- Alerting for runner offline/failures

## 🚀 Advanced Configuration

### Ephemeral Runners

For single-use runners that self-destruct after each job:

```yaml
# In cloud-init
--ephemeral flag during registration
```

### Runner Groups (Organization)

For organization runners:

```hcl
runner_group = "Production"
# Or "Development", "Testing", etc.
```

Configure in GitHub: Organization Settings > Actions > Runner groups

### Autoscaling

Implement autoscaling with:
- Terraform count based on load
- GitHub Actions usage API
- Prometheus metrics
- Custom autoscaling logic

## 📚 Additional Resources

### Related Documentation
- [Cloud-init Scripts](../../scripts/deployment/cloud-init/README.md)
- [Terraform Modules](../../modules/README.md)

### External Links
- [GitHub Actions Self-Hosted Runners](https://docs.github.com/en/actions/hosting-your-own-runners)
- [Runner Releases](https://github.com/actions/runner/releases)
- [Actions Runner Controller](https://github.com/actions/actions-runner-controller) (Kubernetes)

## 🤝 Contributing

Improvements welcome:
- Autoscaling implementation
- Better monitoring integration
- Security enhancements
- Performance optimizations

---

**Maintained by**: HomeLab Team  
**Last Updated**: January 2026  
**Runner Version**: Latest stable
