# Network Infrastructure (Terraform)

This directory contains Terraform configurations for network infrastructure.

## Overview

Manages network components including:
- VLANs and network segments
- Firewall rules
- DNS configurations
- DHCP settings
- VPN configurations

## Files

- `main.tf`: Main network configuration
- `variables.tf`: Input variables
- `outputs.tf`: Output values
- `firewall.tf`: Firewall rules
- `dns.tf`: DNS configurations
- `versions.tf`: Provider version constraints

## Example Configuration

### Main Configuration (main.tf)

```hcl
# Network configuration example
resource "pfsense_vlan" "servers" {
  interface = "lan"
  tag       = 10
  priority  = 0
  description = "Server VLAN"
}

resource "pfsense_interface" "servers_vlan" {
  descr     = "SERVERS"
  if_name   = pfsense_vlan.servers.id
  ipaddr    = "192.168.10.1"
  subnet    = 24
  enable    = true
}
```

### Variables (variables.tf)

```hcl
variable "vlan_config" {
  description = "VLAN configuration"
  type = map(object({
    id          = number
    name        = string
    subnet      = string
    description = string
  }))

  default = {
    management = {
      id          = 1
      name        = "MGMT"
      subnet      = "192.168.1.0/24"
      description = "Management VLAN"
    }
    servers = {
      id          = 10
      name        = "SERVERS"
      subnet      = "192.168.10.0/24"
      description = "Server VLAN"
    }
    iot = {
      id          = 20
      name        = "IOT"
      subnet      = "192.168.20.0/24"
      description = "IoT devices VLAN"
    }
  }
}

variable "firewall_rules" {
  description = "Firewall rules configuration"
  type = list(object({
    action      = string
    protocol    = string
    source      = string
    destination = string
    port        = string
    description = string
  }))
}
```

### Outputs (outputs.tf)

```hcl
output "vlan_ids" {
  description = "Map of VLAN names to IDs"
  value = {
    for k, v in pfsense_vlan.vlans : k => v.tag
  }
}

output "subnet_info" {
  description = "Subnet information for each VLAN"
  value = {
    for k, v in var.vlan_config : k => {
      subnet  = v.subnet
      gateway = cidrhost(v.subnet, 1)
    }
  }
}
```

## Usage

### Initialize and Apply

```bash
# Initialize Terraform
terraform init

# Plan changes
terraform plan -var-file="network.tfvars"

# Apply changes
terraform apply -var-file="network.tfvars"
```

### Example tfvars File

Create `network.tfvars`:

```hcl
firewall_rules = [
  {
    action      = "allow"
    protocol    = "tcp"
    source      = "192.168.1.0/24"
    destination = "192.168.10.0/24"
    port        = "22,443"
    description = "Management to Servers"
  },
  {
    action      = "block"
    protocol    = "any"
    source      = "192.168.20.0/24"
    destination = "192.168.0.0/16"
    port        = "any"
    description = "Block IoT to LAN"
  }
]
```

## Network Architecture

```
Internet
  |
[pfSense]
  |
[Core Switch]
  |
  ├─ VLAN 1  (Management)   - 192.168.1.0/24
  ├─ VLAN 10 (Servers)      - 192.168.10.0/24
  ├─ VLAN 20 (IoT)          - 192.168.20.0/24
  ├─ VLAN 30 (Guest)        - 192.168.30.0/24
  └─ VLAN 40 (Lab)          - 192.168.40.0/24
```

## Firewall Rules

### Default Policy
- Inter-VLAN: Deny all
- Explicit allow rules required

### Standard Rules

1. **Management VLAN**
   - Allow SSH/HTTPS to all VLANs
   - Allow all protocols to internet

2. **Server VLAN**
   - Allow specific service ports
   - Restricted management access

3. **IoT VLAN**
   - Allow internet access only
   - Block all LAN access
   - Allow specific device communications

4. **Guest VLAN**
   - Internet access only
   - Completely isolated from internal networks

5. **Lab VLAN**
   - Flexible rules for testing
   - Isolated from production

## DNS Configuration

```hcl
resource "pfsense_dnsresolver_hostoverride" "server1" {
  hostname    = "server1"
  domain      = "homelab.local"
  ip          = "192.168.10.10"
  description = "Main Application Server"
}
```

## DHCP Configuration

```hcl
resource "pfsense_dhcp_server" "servers" {
  interface   = "servers"
  range_from  = "192.168.10.100"
  range_to    = "192.168.10.200"
  gateway     = "192.168.10.1"
  dnsserver   = ["192.168.1.2", "1.1.1.1"]
  domain      = "homelab.local"
}
```

## Testing

### Validation

```bash
# Validate configuration
terraform validate

# Format code
terraform fmt

# Check for security issues
tfsec .
```

### Network Testing

After applying:

1. Verify VLAN creation
2. Test inter-VLAN routing
3. Validate firewall rules
4. Check DNS resolution
5. Verify DHCP assignments

## Rollback

```bash
# Show previous state
terraform show

# Revert to previous configuration
git checkout HEAD~1 main.tf
terraform apply
```

## Monitoring

Monitor network changes:
- Firewall logs
- Traffic analysis
- Rule hit counts
- Performance metrics

## Security Considerations

- Review all firewall rules before applying
- Use least privilege principle
- Regular rule audits
- Log all denied traffic
- Monitor for anomalies

## Troubleshooting

### Common Issues

**VLAN not created**
- Check switch configuration
- Verify trunk ports
- Review logs

**Firewall rule not working**
- Check rule order
- Verify source/destination
- Review firewall logs

**DNS resolution fails**
- Verify DNS server configuration
- Check firewall rules allow DNS
- Test with nslookup

## Best Practices

- Use descriptive resource names
- Tag all resources appropriately
- Document complex rules
- Version control all changes
- Test in lab environment first
- Implement gradual rollouts

## Integration

### With Ansible

After network provisioning, configure devices:

```bash
cd ../../ansible
ansible-playbook -i inventory/production playbooks/configure-network.yml
```

### With Monitoring

Update monitoring after network changes:

```bash
# Update Prometheus targets
# Update Grafana dashboards
# Configure alerting rules
```

## References

- [pfSense Documentation](https://docs.netgate.com/pfsense/en/latest/)
- [Terraform pfSense Provider](https://registry.terraform.io/providers/frankrefischer/pfsense/latest/docs)
- [Network Design Best Practices](https://www.cisco.com/c/en/us/support/docs/lan-switching/vlan/10023-4.html)
