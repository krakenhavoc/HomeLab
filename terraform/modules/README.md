# Terraform Modules

Reusable Terraform modules for homelab infrastructure components.

## 📋 Overview

This directory contains modular, reusable Terraform configurations that can be used across different deployments. Modules encapsulate common infrastructure patterns and promote code reuse.

## 📁 Directory Structure

```
modules/
├── compute/           # Compute resource modules
│   ├── pm-cloudinit-vm/     # Proxmox cloud-init VM (pm provider)
│   ├── pve-cloudinit-vm/    # Proxmox cloud-init VM (pve provider)
│   └── README.md
├── network/           # Network infrastructure modules
│   └── README.md
└── README.md          # This file
```

## 🏗️ Available Modules

### Compute Modules

#### pm-cloudinit-vm
Proxmox virtual machine module using the Proxmox Terraform provider (bpg/proxmox).

**Use Cases:**
- Create VMs with cloud-init support
- Modern Proxmox provider features
- Advanced VM configuration options

**Quick Example:**
```hcl
module "web_server" {
  source = "./modules/compute/pm-cloudinit-vm"
  
  vm_name     = "web-01"
  target_node = "pve"
  cpu_cores   = 2
  memory_mb   = 4096
  disk_size   = "50G"
}
```

See [compute/pm-cloudinit-vm/README.md](compute/pm-cloudinit-vm/README.md) for details.

#### pve-cloudinit-vm
Proxmox virtual machine module using the Telmate Proxmox provider.

**Use Cases:**
- Legacy deployments
- Compatibility with existing code
- Well-established provider

**Quick Example:**
```hcl
module "app_server" {
  source = "./modules/compute/pve-cloudinit-vm"
  
  vm_name     = "app-01"
  target_node = "pve"
  cpu_cores   = 4
  memory_mb   = 8192
}
```

See [compute/pve-cloudinit-vm/README.md](compute/pve-cloudinit-vm/README.md) for details.

### Network Modules

Network infrastructure modules for VLAN, firewall, and routing configuration.

**Planned modules:**
- VLAN configuration
- Firewall rules
- DNS/DHCP setup
- VPN configuration

See [network/README.md](network/README.md) for details.

## 🚀 Using Modules

### Basic Usage

```hcl
module "example" {
  source = "./modules/compute/pm-cloudinit-vm"
  
  # Required variables
  vm_name     = "my-vm"
  target_node = "pve"
  
  # Optional variables
  cpu_cores = 2
  memory_mb = 4096
}
```

### Module Outputs

Access module outputs in your main configuration:

```hcl
output "vm_ip" {
  value = module.example.vm_ip
}

output "vm_id" {
  value = module.example.vm_id
}
```

### Multiple Instances

Create multiple VMs using `count` or `for_each`:

```hcl
# Using count
module "worker" {
  source = "./modules/compute/pm-cloudinit-vm"
  count  = 3
  
  vm_name     = "worker-${count.index + 1}"
  target_node = "pve"
  cpu_cores   = 2
  memory_mb   = 4096
}

# Using for_each
variable "vms" {
  default = {
    web-01 = { cores = 2, memory = 4096 }
    web-02 = { cores = 2, memory = 4096 }
    db-01  = { cores = 4, memory = 8192 }
  }
}

module "servers" {
  source   = "./modules/compute/pm-cloudinit-vm"
  for_each = var.vms
  
  vm_name     = each.key
  target_node = "pve"
  cpu_cores   = each.value.cores
  memory_mb   = each.value.memory
}
```

## 📝 Module Development

### Creating a New Module

1. **Create directory structure:**
   ```bash
   mkdir -p modules/category/module-name
   cd modules/category/module-name
   ```

2. **Create required files:**
   ```bash
   touch main.tf variables.tf outputs.tf README.md
   touch versions.tf  # Optional but recommended
   ```

3. **Define module interface:**
   - `variables.tf` - Input variables
   - `outputs.tf` - Return values
   - `main.tf` - Resource definitions
   - `README.md` - Documentation

### Module Structure

```
module-name/
├── main.tf              # Main resource definitions
├── variables.tf         # Input variable declarations
├── outputs.tf           # Output value declarations
├── versions.tf          # Provider version constraints
├── README.md            # Module documentation
├── examples/            # Usage examples (optional)
│   └── basic/
│       └── main.tf
└── tests/              # Automated tests (optional)
    └── basic_test.go
```

### Module Standards

#### variables.tf Template
```hcl
variable "vm_name" {
  description = "Name of the virtual machine"
  type        = string
  
  validation {
    condition     = length(var.vm_name) > 0
    error_message = "VM name must not be empty."
  }
}

variable "cpu_cores" {
  description = "Number of CPU cores"
  type        = number
  default     = 2
  
  validation {
    condition     = var.cpu_cores > 0 && var.cpu_cores <= 16
    error_message = "CPU cores must be between 1 and 16."
  }
}
```

#### outputs.tf Template
```hcl
output "vm_id" {
  description = "The ID of the created VM"
  value       = resource_type.resource_name.id
}

output "vm_ip" {
  description = "The IP address of the VM"
  value       = resource_type.resource_name.ip_address
}
```

#### README.md Template
```markdown
# Module Name

Brief description of what the module does.

## Usage

\`\`\`hcl
module "example" {
  source = "./path/to/module"
  
  required_var = "value"
}
\`\`\`

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| var1 | Description | string | n/a | yes |
| var2 | Description | number | 2 | no |

## Outputs

| Name | Description |
|------|-------------|
| output1 | Description |
| output2 | Description |
```

## 🧪 Testing Modules

### Manual Testing

```bash
# Create test directory
mkdir -p modules/compute/my-module/examples/test

# Create test configuration
cat > examples/test/main.tf << 'EOF'
module "test" {
  source = "../.."
  
  # Test configuration
  vm_name = "test-vm"
}

output "test_output" {
  value = module.test.vm_id
}
EOF

# Run test
cd examples/test
terraform init
terraform plan
```

### Automated Testing

Consider using:
- **Terratest** - Go-based testing framework
- **Kitchen-Terraform** - Infrastructure testing
- **terraform-compliance** - BDD testing

Example Terratest:
```go
package test

import (
    "testing"
    "github.com/gruntwork-io/terratest/modules/terraform"
)

func TestModule(t *testing.T) {
    terraformOptions := &terraform.Options{
        TerraformDir: "../examples/basic",
    }
    
    defer terraform.Destroy(t, terraformOptions)
    terraform.InitAndApply(t, terraformOptions)
    
    // Add assertions here
}
```

## 📊 Module Versioning

### Using Git Tags

```bash
# Tag a module version
git tag -a modules/compute/my-module/v1.0.0 -m "Release v1.0.0"
git push --tags

# Reference specific version
module "example" {
  source = "git::https://github.com/org/repo.git//modules/compute/my-module?ref=v1.0.0"
}
```

### Semantic Versioning

Follow [Semantic Versioning](https://semver.org/):
- **MAJOR** - Incompatible API changes
- **MINOR** - Backwards-compatible functionality
- **PATCH** - Backwards-compatible bug fixes

## 🔒 Security Best Practices

### Input Validation

Always validate inputs:
```hcl
variable "vm_name" {
  validation {
    condition     = can(regex("^[a-z0-9-]+$", var.vm_name))
    error_message = "VM name must contain only lowercase letters, numbers, and hyphens."
  }
}
```

### Sensitive Data

Mark sensitive outputs:
```hcl
output "api_key" {
  value     = random_password.api_key.result
  sensitive = true
}
```

### Principle of Least Privilege

- Minimize required permissions
- Use specific provider configurations
- Avoid overly broad IAM roles

## 📚 Best Practices

### 1. Documentation
- Comprehensive README for each module
- Document all variables and outputs
- Include usage examples
- Explain design decisions

### 2. Naming Conventions
- Use descriptive module names
- Consistent variable naming
- Clear output names
- Follow Terraform style guide

### 3. Defaults
- Provide sensible defaults
- Make required vars explicit
- Document default values

### 4. Composability
- Keep modules focused
- Avoid deep nesting
- Design for reusability
- Minimize dependencies

### 5. Validation
- Validate inputs
- Check for edge cases
- Provide helpful error messages
- Test thoroughly

## 🔄 Updating Modules

### Breaking Changes

When making breaking changes:
1. Increment MAJOR version
2. Document migration path
3. Provide deprecation warnings
4. Support old version temporarily

### Non-Breaking Changes

For new features:
1. Increment MINOR version
2. Add new optional variables
3. Maintain backward compatibility
4. Update documentation

### Bug Fixes

For bug fixes:
1. Increment PATCH version
2. Document fixed issues
3. Add tests to prevent regression

## 📖 Additional Resources

### Internal Links
- [Compute Module README](compute/README.md)
- [Network Module README](network/README.md)
- [Deployments](../deployments/README.md)

### External Links
- [Terraform Module Documentation](https://www.terraform.io/docs/language/modules/index.html)
- [Terraform Module Registry](https://registry.terraform.io/)
- [Terraform Best Practices](https://www.terraform-best-practices.com/)
- [Terratest Documentation](https://terratest.gruntwork.io/)

## 🤝 Contributing

When contributing modules:

1. Follow the module structure standards
2. Include comprehensive documentation
3. Add usage examples
4. Write tests
5. Validate inputs
6. Submit PR with description

## 📧 Support

For module-related issues:
- Check module README
- Review examples
- Open an issue with full context
- Include Terraform version and provider versions

---

**Maintained by**: HomeLab Team  
**Last Updated**: January 2026
