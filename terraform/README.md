# Terraform Infrastructure as Code

This directory contains Terraform configurations for managing homelab infrastructure.

## Directory Structure

```
terraform/
├── network/          # Network infrastructure
├── compute/          # Virtual machines and compute resources
└── storage/          # Storage configurations
```

## Prerequisites

- Terraform >= 1.0
- Appropriate provider credentials
- Network access to infrastructure

## Getting Started

### Install Terraform

```bash
# macOS
brew install terraform

# Linux
wget https://releases.hashicorp.com/terraform/1.6.0/terraform_1.6.0_linux_amd64.zip
unzip terraform_1.6.0_linux_amd64.zip
sudo mv terraform /usr/local/bin/
```

### Verify Installation

```bash
terraform version
```

## Usage

### Initialize Terraform

```bash
cd terraform/compute
terraform init
```

### Plan Changes

```bash
terraform plan -out=tfplan
```

### Apply Changes

```bash
terraform apply tfplan
```

### Destroy Resources

```bash
terraform destroy
```

## Environment Variables

Create a `.env` file (never commit this):

```bash
# Proxmox
export PM_API_URL="https://proxmox.homelab.local:8006/api2/json"
export PM_API_TOKEN_ID="terraform@pam!terraform"
export PM_API_TOKEN_SECRET="your-secret-here"

# Other providers
export TF_VAR_api_key="your-api-key"
```

## Best Practices

### State Management

- Use remote state backend for team collaboration
- Enable state locking
- Regular state backups

```hcl
terraform {
  backend "s3" {
    bucket = "terraform-state"
    key    = "homelab/terraform.tfstate"
    region = "us-east-1"
  }
}
```

### Variable Management

- Use `terraform.tfvars` for environment-specific values
- Never commit sensitive values
- Use variable validation

```hcl
variable "vm_count" {
  description = "Number of VMs to create"
  type        = number
  default     = 3

  validation {
    condition     = var.vm_count > 0 && var.vm_count <= 10
    error_message = "VM count must be between 1 and 10."
  }
}
```

### Module Usage

- Create reusable modules
- Version module sources
- Document module inputs/outputs

```hcl
module "web_servers" {
  source = "./modules/vm"

  count         = 3
  vm_name       = "web-server"
  cpu_cores     = 2
  memory_mb     = 4096
  disk_size_gb  = 50
}
```

## Providers Used

### Proxmox Provider

```hcl
terraform {
  required_providers {
    proxmox = {
      source  = "telmate/proxmox"
      version = "~> 2.9"
    }
  }
}

provider "proxmox" {
  pm_api_url          = var.proxmox_api_url
  pm_api_token_id     = var.proxmox_api_token_id
  pm_api_token_secret = var.proxmox_api_token_secret
  pm_tls_insecure     = true
}
```

### Other Providers

- **Docker**: Container management
- **Kubernetes**: K8s resources
- **Local**: Local file management
- **External**: External data sources

## Common Commands

```bash
# Format code
terraform fmt -recursive

# Validate configuration
terraform validate

# Show current state
terraform show

# List resources
terraform state list

# Import existing resource
terraform import proxmox_vm_qemu.example 100

# Refresh state
terraform refresh

# Output values
terraform output
```

## Workflows

### Creating New VMs

1. Define VM configuration in `compute/vms.tf`
2. Set variables in `compute/terraform.tfvars`
3. Run `terraform plan` to preview
4. Run `terraform apply` to create
5. Verify VM creation in Proxmox UI

### Network Changes

1. Update network configuration in `network/`
2. Plan and review changes
3. Apply during maintenance window
4. Verify connectivity

### Storage Provisioning

1. Define storage resources in `storage/`
2. Consider backup implications
3. Apply changes
4. Update backup configurations

## Troubleshooting

### Common Issues

**Provider Authentication Fails**
```bash
# Verify credentials
echo $PM_API_TOKEN_SECRET
# Check API endpoint
curl -k $PM_API_URL
```

**State Lock Issues**
```bash
# Force unlock (use with caution)
terraform force-unlock <lock-id>
```

**Resource Already Exists**
```bash
# Import existing resource
terraform import <resource_type>.<name> <id>
```

## Security Considerations

- Never commit `.tfvars` files with secrets
- Use environment variables for sensitive data
- Implement RBAC for Terraform operations
- Regular security audits of configurations
- Use `terraform plan` before `apply`

## CI/CD Integration

### GitHub Actions Example

```yaml
name: Terraform

on:
  push:
    branches: [ main ]
  pull_request:
    branches: [ main ]

jobs:
  terraform:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - uses: hashicorp/setup-terraform@v2
      - run: terraform init
      - run: terraform validate
      - run: terraform plan
```

## Documentation

Each subdirectory contains:
- `README.md`: Specific documentation
- `variables.tf`: Input variables
- `outputs.tf`: Output values
- `main.tf`: Main configuration
- `versions.tf`: Provider versions

## Resources

- [Terraform Documentation](https://www.terraform.io/docs)
- [Proxmox Provider Docs](https://registry.terraform.io/providers/Telmate/proxmox/latest/docs)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Learn Terraform](https://learn.hashicorp.com/terraform)

## Future Enhancements

- Implement Terraform Cloud for state management
- Add automated testing with Terratest
- Create custom provider for homelab devices
- Implement policy as code with Sentinel
- Add drift detection automation
