# Terraform Deployments

This directory contains production-ready Terraform deployment configurations for various homelab services and infrastructure.

## 📁 Directory Structure

```
deployments/
├── home-lab/          # Main Kubernetes cluster deployment
├── plex/              # Plex media server deployment
├── gh-runner/         # GitHub Actions self-hosted runner
└── README.md          # This file
```

## 🚀 Available Deployments

### home-lab
Complete Kubernetes cluster deployment on Proxmox using cloud-init.

**Features:**
- Kubernetes v1.29 cluster (1 master + 2 workers)
- Containerd runtime
- Calico CNI networking
- Cloud-init automated provisioning
- Terraform modules for VM deployment

**Quick Start:**
```bash
cd home-lab
terraform init
terraform plan
terraform apply
```

See [home-lab/README.md](home-lab/README.md) for detailed documentation.

### plex
Plex media server deployment on Proxmox VM.

**Features:**
- Ubuntu VM with Plex Media Server
- Cloud-init configuration
- Storage mount points
- Network configuration

**Quick Start:**
```bash
cd plex
terraform init
terraform plan
terraform apply
```

See [plex/README.md](plex/README.md) for detailed documentation.

### gh-runner
Self-hosted GitHub Actions runner deployment.

**Features:**
- GitHub Actions runner VM
- Automated registration
- Docker support
- Cloud-init provisioning

**Quick Start:**
```bash
cd gh-runner
terraform init
terraform plan
terraform apply
```

See [gh-runner/README.md](gh-runner/README.md) for detailed documentation.

## 🛠️ Prerequisites

### Required Tools
- **Terraform** >= 1.0
- **Proxmox VE** 7.x+ with API access
- **SSH Keys** for VM access
- Network access to Proxmox API

### Environment Setup

Create a `.env` file (never commit this):

```bash
# Proxmox Configuration
export PM_API_URL="https://proxmox.homelab.local:8006/api2/json"
export PM_API_TOKEN_ID="terraform@pam!terraform"
export PM_API_TOKEN_SECRET="your-secret-here"

# SSH Configuration
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
```

Load environment:
```bash
source .env
```

## 📝 Common Workflow

### 1. Initialize Deployment

```bash
cd <deployment-name>
terraform init
```

### 2. Review Configuration

Edit `terraform.tfvars` or environment-specific files in `env/` directory:

```hcl
# Example terraform.tfvars
vm_count = 3
cpu_cores = 2
memory_mb = 4096
```

### 3. Plan Changes

```bash
terraform plan -out=tfplan
```

### 4. Apply Configuration

```bash
terraform apply tfplan
```

### 5. Verify Deployment

```bash
terraform output
```

### 6. Cleanup (if needed)

```bash
terraform destroy
```

## 🏗️ Deployment Structure

Each deployment follows a standard structure:

```
deployment-name/
├── main.tf              # Main configuration
├── variables.tf         # Input variables
├── outputs.tf           # Output values
├── providers.tf         # Provider configuration
├── versions.tf          # Version constraints
├── backend.tf           # State backend configuration
├── locals.tf            # Local values (optional)
├── data.tf              # Data sources (optional)
├── env/                 # Environment-specific configs
│   └── prod/
│       └── terraform.tfvars
└── README.md            # Deployment documentation
```

## 🔐 Security Best Practices

### Credentials Management
- Never commit sensitive values
- Use environment variables for secrets
- Enable Terraform state encryption
- Restrict API token permissions
- Use separate tokens per deployment

### State Management
- Use remote state backend
- Enable state locking
- Regular state backups
- Restrict state file access

### Network Security
- Deploy in appropriate VLANs
- Configure firewall rules
- Use SSH keys (no passwords)
- Enable Proxmox firewall

## 📊 State Management

### Local State (Development)

Default configuration uses local state files:
```hcl
# backend.tf (commented out)
# terraform {
#   backend "s3" {
#     ...
#   }
# }
```

### Remote State (Production)

For production deployments, configure remote backend:

```hcl
# backend.tf
terraform {
  backend "s3" {
    bucket         = "homelab-terraform-state"
    key            = "deployments/<deployment-name>/terraform.tfstate"
    region         = "us-east-1"
    encrypt        = true
    dynamodb_table = "terraform-state-lock"
  }
}
```

## 🔄 Updating Deployments

### Standard Update Process

1. **Review Changes**
   ```bash
   git pull origin main
   terraform plan
   ```

2. **Test in Development**
   ```bash
   cd env/dev
   terraform apply
   ```

3. **Apply to Production**
   ```bash
   cd env/prod
   terraform apply
   ```

### Rolling Updates

For minimal downtime:
```bash
# Update one resource at a time
terraform apply -target=module.worker[0]
terraform apply -target=module.worker[1]
```

## 🧪 Testing

### Validation

```bash
# Validate syntax
terraform validate

# Format code
terraform fmt -recursive

# Security scanning
tfsec .
```

### Dry Run

Always test with `-dry-run` or plan before applying:
```bash
terraform plan -out=tfplan
# Review the plan carefully
terraform apply tfplan
```

## 🐛 Troubleshooting

### Common Issues

**Initialization Fails**
```bash
# Clear cache and reinitialize
rm -rf .terraform .terraform.lock.hcl
terraform init
```

**State Lock Issues**
```bash
# View current state
terraform state list

# Force unlock (use with caution)
terraform force-unlock <lock-id>
```

**Resource Already Exists**
```bash
# Import existing resource
terraform import <resource_type>.<name> <id>
```

**API Connection Fails**
```bash
# Verify environment variables
echo $PM_API_URL
echo $PM_API_TOKEN_ID

# Test API connection
curl -k "$PM_API_URL/version"
```

## 📚 Additional Resources

### Documentation
- [Main Terraform README](../README.md)
- [Terraform Modules](../modules/README.md)
- [Cloud-init Configurations](../../scripts/deployment/cloud-init/README.md)

### External Links
- [Terraform Documentation](https://www.terraform.io/docs)
- [Proxmox Provider](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)

## 🤝 Contributing

When adding new deployments:

1. Follow the standard directory structure
2. Include comprehensive README.md
3. Document all variables and outputs
4. Provide example configurations
5. Test thoroughly before committing
6. Update this master README

## 📧 Support

For deployment-specific issues:
- Check deployment README
- Review Terraform logs
- Open an issue with full context
- Include Terraform version and provider versions

---

**Maintained by**: HomeLab Team  
**Last Updated**: January 2026
