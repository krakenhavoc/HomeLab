# Network Setup Guide

## Overview

This document describes the network architecture and setup for the homelab environment.

## Network Topology

The homelab network is segmented into multiple VLANs for security and organization:

### VLAN Structure

| VLAN ID | Name | Subnet | Purpose |
|---------|------|--------|---------|
| 1 | Management | 192.168.1.0/24 | Network management and administration |
| 10 | Servers | 192.168.10.0/24 | Server infrastructure |
| 20 | IoT | 192.168.20.0/24 | Internet of Things devices |
| 30 | Guest | 192.168.30.0/24 | Guest network (isolated) |
| 40 | Lab | 192.168.40.0/24 | Testing and development |

## Network Devices

### Core Infrastructure

- **Router/Firewall**: pfSense/OPNsense
  - Handles routing between VLANs
  - Firewall rules and security policies
  - VPN access for remote management
  
- **Switch**: Managed Layer 3 Switch
  - VLAN trunking and routing
  - Port-based VLAN assignment
  - Link aggregation (LAGG)

- **Access Points**: UniFi AP
  - Multiple SSIDs mapped to VLANs
  - Guest network isolation
  - WPA3 encryption

## Network Services

### DNS
- Primary DNS: Pi-hole (ad-blocking)
- Secondary DNS: Local recursive resolver
- Internal domain: homelab.local

### DHCP
- DHCP server per VLAN
- Static reservations for servers
- Dynamic allocation for clients

### VPN
- WireGuard for remote access
- Split-tunnel configuration
- MFA authentication

## Security

### Firewall Rules

1. **Default Deny**: All inter-VLAN traffic blocked by default
2. **Explicit Allow**: Only required traffic permitted
3. **Guest Isolation**: Complete isolation from internal networks
4. **IoT Restrictions**: Limited outbound access, no LAN access

### Network Monitoring

- Traffic analysis with ntopng
- IDS/IPS with Suricata
- Log aggregation and alerting

## Configuration Examples

### VLAN Configuration (Example)

```bash
# Switch VLAN configuration
vlan 10
  name Servers
  vlan 20
  name IoT
```

### Firewall Rules (Example)

```
# Allow management VLAN to access servers
allow from 192.168.1.0/24 to 192.168.10.0/24 port 22,443

# Block IoT from accessing internal networks
block from 192.168.20.0/24 to 192.168.0.0/16
```

## Troubleshooting

### Common Issues

1. **VLAN Tagging Problems**
   - Verify trunk ports are configured correctly
   - Check switch VLAN membership

2. **DHCP Not Working**
   - Verify DHCP relay configuration
   - Check firewall rules allow DHCP traffic

3. **DNS Resolution Failures**
   - Check DNS server accessibility
   - Verify upstream DNS configuration

## Future Enhancements

- Implement 10Gbe backbone
- Add redundant internet connections
- Deploy SD-WAN capabilities
- Enhance network monitoring
