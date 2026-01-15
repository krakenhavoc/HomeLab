# Cloud-init Configurations

Cloud-init configuration files for automated VM provisioning and setup.

## 📋 Overview

This directory contains cloud-init YAML files and scripts used to automatically configure VMs during first boot. These configurations are used by Terraform deployments to provision fully configured systems without manual intervention.

## 📁 Directory Structure

```
cloud-init/
├── kubernetes/        # Kubernetes cluster node configurations
│   ├── setup-k8s-master.yaml
│   ├── setup-k8s-worker.yaml
│   └── calico-patch.sh
├── plex/              # Plex Media Server configuration
│   └── setup-plex-host.yaml
├── snippets/          # Reusable configuration snippets
│   ├── setup-k8s-master.yaml
│   ├── setup-k8s-worker.yaml
│   └── setup-gh-runner.yaml
├── templates/         # VM template creation scripts
│   └── update-noble-template.sh
└── README.md          # This file
```

## 🚀 What is Cloud-init?

Cloud-init is the industry standard for cloud instance initialization. It handles:
- **System configuration** - Hostname, network, users
- **Package installation** - Installing required software
- **File management** - Creating and modifying files
- **Command execution** - Running scripts and commands
- **Service management** - Enabling and starting services

## 📝 Configuration Files

### Kubernetes Configurations

#### kubernetes/setup-k8s-master.yaml
Configures Kubernetes master/control plane node with:
- Containerd runtime installation
- Kubernetes packages (kubeadm, kubelet, kubectl)
- Cluster initialization with kubeadm
- Calico CNI network plugin
- Pod network configuration
- kubectl setup for root user

**Used by**: `terraform/deployments/home-lab`

#### kubernetes/setup-k8s-worker.yaml
Configures Kubernetes worker nodes with:
- Containerd runtime installation
- Kubernetes packages
- Automatic cluster join
- Node readiness verification

**Used by**: `terraform/deployments/home-lab`

#### kubernetes/calico-patch.sh
Script to patch Calico deployment for specific network configurations.

### Plex Configuration

#### plex/setup-plex-host.yaml
Configures Plex Media Server with:
- System updates and dependencies
- Plex repository setup
- Plex Media Server installation
- Storage mount configuration
- Service enablement and startup

**Used by**: `terraform/deployments/plex`

### Snippets

Reusable cloud-init snippets that can be referenced by Proxmox:

#### snippets/setup-k8s-master.yaml
Master node configuration snippet for Proxmox snippets storage.

#### snippets/setup-k8s-worker.yaml
Worker node configuration snippet for Proxmox snippets storage.

#### snippets/setup-gh-runner.yaml
GitHub Actions runner setup snippet with:
- Docker installation
- Runner binary download
- Runner registration
- Service configuration

**Used by**: `terraform/deployments/gh-runner`

### Templates

#### templates/update-noble-template.sh
Script to create or update Ubuntu Noble (24.04) cloud-init templates in Proxmox.

## 🔧 Cloud-init Syntax

### Basic Structure

```yaml
#cloud-config

# User configuration
users:
  - name: ubuntu
    sudo: ALL=(ALL) NOPASSWD:ALL
    shell: /bin/bash
    ssh_authorized_keys:
      - ssh-rsa AAAA...

# Package updates
package_update: true
package_upgrade: true

# Install packages
packages:
  - vim
  - git
  - curl

# Run commands
runcmd:
  - echo "Hello, World!"
  - systemctl enable myservice

# Write files
write_files:
  - path: /etc/myapp/config.yaml
    content: |
      key: value
    permissions: '0644'
```

### Common Modules

#### packages
```yaml
packages:
  - package1
  - package2
  - package3
```

#### runcmd
```yaml
runcmd:
  - apt update
  - apt install -y software
  - systemctl enable service
  - systemctl start service
```

#### write_files
```yaml
write_files:
  - path: /etc/config.conf
    content: |
      configuration content
    permissions: '0644'
    owner: root:root
```

#### ssh_authorized_keys
```yaml
ssh_authorized_keys:
  - ssh-ed25519 AAAA... user@host
```

## 📦 Using with Terraform

### Method 1: Inline Configuration

```hcl
resource "proxmox_vm_qemu" "example" {
  # ... other configuration ...
  
  # Inline cloud-init
  cicustom = "user=local:snippets/my-config.yaml"
  
  # Or use heredoc
  cloudinit_custom_user_data = <<-EOF
    #cloud-config
    packages:
      - vim
    runcmd:
      - echo "Hello"
  EOF
}
```

### Method 2: External File

```hcl
resource "proxmox_vm_qemu" "example" {
  # ... other configuration ...
  
  # Reference Proxmox snippet
  cicustom = "user=local:snippets/setup-k8s-master.yaml"
}
```

### Method 3: Template File

```hcl
data "template_file" "user_data" {
  template = file("${path.module}/cloud-init/config.yaml")
  
  vars = {
    hostname = var.hostname
    ssh_key  = var.ssh_public_key
  }
}

resource "proxmox_vm_qemu" "example" {
  cicustom = "user=local:snippets/${data.template_file.user_data.rendered}"
}
```

## 🧪 Testing Cloud-init

### Validate Syntax

```bash
# Install cloud-init
apt install cloud-init

# Validate configuration
cloud-init schema --config-file config.yaml

# Check for errors
echo $?  # Should be 0 if valid
```

### Test Locally

```bash
# Run cloud-init in test mode
sudo cloud-init init --local

# View logs
sudo cat /var/log/cloud-init.log
sudo cat /var/log/cloud-init-output.log
```

### Debug on VM

```bash
# SSH to VM after deployment
ssh user@vm-ip

# Check cloud-init status
cloud-init status

# View detailed status
cloud-init status --long

# Check logs
sudo cat /var/log/cloud-init.log
sudo cat /var/log/cloud-init-output.log

# Re-run cloud-init (for testing)
sudo cloud-init clean
sudo cloud-init init
```

## 🐛 Troubleshooting

### Cloud-init Not Running

```bash
# Check if cloud-init is installed
dpkg -l | grep cloud-init

# Check service status
systemctl status cloud-init

# Enable and start
systemctl enable cloud-init
systemctl start cloud-init
```

### Configuration Not Applied

```bash
# Verify cloud-init ran
ls -la /var/lib/cloud/instance

# Check for errors in logs
grep -i error /var/log/cloud-init.log
grep -i failed /var/log/cloud-init-output.log

# Verify configuration was read
sudo cloud-init query -a
```

### Packages Not Installing

```bash
# Check package installation logs
grep -A 10 "package_" /var/log/cloud-init.log

# Manually install to see errors
apt update
apt install -y package-name
```

### Scripts Not Executing

```bash
# Check runcmd execution
grep -A 50 "runcmd" /var/log/cloud-init-output.log

# Verify script permissions
ls -la /var/lib/cloud/instance/scripts/

# Run script manually
bash -x /var/lib/cloud/instance/scripts/runcmd
```

## 💡 Best Practices

### 1. Idempotency
Ensure scripts can run multiple times safely:
```yaml
runcmd:
  - |
    if ! command -v docker &> /dev/null; then
      curl -fsSL https://get.docker.com | sh
    fi
```

### 2. Error Handling
Add error checking to scripts:
```yaml
runcmd:
  - set -e  # Exit on error
  - set -x  # Debug output
  - apt update || exit 1
  - apt install -y package || exit 1
```

### 3. Logging
Add logging to track execution:
```yaml
runcmd:
  - echo "Starting configuration..." | tee -a /var/log/setup.log
  - apt update 2>&1 | tee -a /var/log/setup.log
```

### 4. Timeouts
Some operations need time:
```yaml
runcmd:
  - timeout 300 systemctl start service
  - sleep 10 && curl http://localhost:8080/health
```

### 5. Validation
Verify results:
```yaml
runcmd:
  - apt install -y docker.io
  - docker --version || exit 1
  - systemctl is-active docker || exit 1
```

## 🔐 Security Considerations

### Don't Store Secrets

Never put secrets directly in cloud-init:
```yaml
# BAD - Don't do this
runcmd:
  - export API_KEY="secret123"
```

Use environment variables or secrets management:
```yaml
# GOOD - Use parameter or Vault
runcmd:
  - export API_KEY=$(vault kv get -field=key secret/api)
```

### SSH Keys Only

Always use SSH keys:
```yaml
users:
  - name: ubuntu
    ssh_authorized_keys:
      - ssh-ed25519 AAAA...
```

### Disable Password Auth

```yaml
ssh_pwauth: false
```

### Update Systems

```yaml
package_update: true
package_upgrade: true
```

## 📚 Examples

### Basic Web Server

```yaml
#cloud-config
package_update: true
packages:
  - nginx
  - certbot
  
write_files:
  - path: /var/www/html/index.html
    content: |
      <h1>Hello from Cloud-init!</h1>
    
runcmd:
  - systemctl enable nginx
  - systemctl start nginx
```

### Docker Host

```yaml
#cloud-config
package_update: true

runcmd:
  - curl -fsSL https://get.docker.com | sh
  - usermod -aG docker ubuntu
  - systemctl enable docker
  - systemctl start docker
  - docker run -d -p 80:80 nginx
```

### Development Environment

```yaml
#cloud-config
packages:
  - git
  - vim
  - tmux
  - docker.io
  
users:
  - name: developer
    groups: docker, sudo
    shell: /bin/bash
    sudo: ALL=(ALL) NOPASSWD:ALL
    ssh_authorized_keys:
      - ssh-ed25519 AAAA...
      
runcmd:
  - git clone https://github.com/user/dotfiles /home/developer/.dotfiles
  - chown -R developer:developer /home/developer/.dotfiles
```

## 📖 Additional Resources

### Related Documentation
- [Terraform Deployments](../../../terraform/deployments/README.md)
- [Main Documentation](../../../docs/README.md)

### External Links
- [Cloud-init Documentation](https://cloudinit.readthedocs.io/)
- [Cloud-init Examples](https://cloudinit.readthedocs.io/en/latest/topics/examples.html)
- [Cloud-init Modules](https://cloudinit.readthedocs.io/en/latest/topics/modules.html)
- [Proxmox Cloud-init](https://pve.proxmox.com/wiki/Cloud-Init_Support)

## 🤝 Contributing

When adding cloud-init configurations:

1. Test thoroughly before committing
2. Document what the configuration does
3. Add error handling
4. Follow naming conventions
5. Include usage examples
6. Update this README

---

**Maintained by**: HomeLab Team  
**Last Updated**: January 2026
