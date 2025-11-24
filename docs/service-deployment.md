# Service Deployment Guide

## Overview

This guide covers the deployment and management of services running in the homelab environment.

## Infrastructure Platform

### Virtualization
- **Proxmox VE**: Primary hypervisor for virtual machines
- **Docker**: Container runtime for microservices
- **Kubernetes**: Container orchestration (K3s)

## Core Services

### 1. Proxmox Virtual Environment

#### Installation
- Installed on bare metal servers
- ZFS storage pools for VMs
- High availability cluster configuration

#### VM Templates
- Ubuntu Server 22.04 LTS
- Debian 12
- Rocky Linux 9
- Windows Server 2022

### 2. Docker Services

#### Docker Compose Stack

```yaml
# Example docker-compose.yml structure
version: '3.8'
services:
  # Service definitions
  portainer:
    image: portainer/portainer-ce:latest
    container_name: portainer
    restart: unless-stopped
    # ... configuration
```

#### Common Services
- **Portainer**: Docker management UI
- **Nginx Proxy Manager**: Reverse proxy
- **Pi-hole**: Network-wide ad blocking
- **Home Assistant**: Home automation
- **Plex/Jellyfin**: Media server
- **Nextcloud**: File sync and share

### 3. Kubernetes Cluster

#### Cluster Configuration
- **Control Plane**: 3 nodes for HA
- **Worker Nodes**: 3+ nodes for workloads
- **Storage**: Longhorn for persistent volumes
- **Networking**: Flannel CNI

#### Deployed Applications
- **Monitoring Stack**
  - Prometheus for metrics
  - Grafana for visualization
  - Alertmanager for notifications
  
- **Logging Stack**
  - Loki for log aggregation
  - Promtail for log collection
  
- **Ingress**
  - Traefik ingress controller
  - Cert-manager for TLS certificates

## Service Categories

### Infrastructure Services

1. **DNS & DHCP**
   - Pi-hole for DNS filtering
   - ISC DHCP server
   - Automated DNS record management

2. **Monitoring & Observability**
   - Prometheus + Grafana stack
   - Uptime Kuma for service monitoring
   - Netdata for real-time metrics

3. **Backup & Storage**
   - TrueNAS for NAS services
   - Proxmox Backup Server
   - Automated backup schedules

### Application Services

1. **Media Services**
   - Plex/Jellyfin media server
   - Sonarr/Radarr automation
   - Transmission for downloads

2. **Productivity**
   - Nextcloud for file storage
   - Bookstack for documentation
   - Vaultwarden for password management

3. **Development**
   - GitLab CE for source control
   - Jenkins for CI/CD
   - Minio for object storage

## Deployment Workflow

### Standard Deployment Process

1. **Planning**
   - Define resource requirements
   - Identify dependencies
   - Plan network access

2. **Infrastructure Provisioning**
   ```bash
   # Using Terraform
   cd terraform/compute
   terraform init
   terraform plan
   terraform apply
   ```

3. **Configuration Management**
   ```bash
   # Using Ansible
   cd ansible/playbooks
   ansible-playbook -i ../inventory/production deploy-service.yml
   ```

4. **Validation**
   - Health checks
   - Service monitoring
   - Log verification

## Service Management

### Starting/Stopping Services

```bash
# Docker services
docker-compose up -d
docker-compose down

# Kubernetes services
kubectl apply -f deployment.yaml
kubectl delete -f deployment.yaml

# Systemd services
systemctl start service-name
systemctl stop service-name
```

### Updates and Maintenance

- Weekly security updates
- Monthly version upgrades
- Quarterly service reviews

## Backup Strategy

### What's Backed Up
- VM configurations and disks
- Docker volumes
- Application data
- Configuration files

### Backup Schedule
- **Daily**: Critical data
- **Weekly**: Full VM backups
- **Monthly**: Archive snapshots

## Monitoring and Alerts

### Metrics Collected
- CPU, memory, disk usage
- Network traffic
- Service uptime
- Application-specific metrics

### Alert Conditions
- Service down > 5 minutes
- Disk usage > 85%
- High CPU/memory usage
- Failed backups

## Troubleshooting

### Common Issues

1. **Container Won't Start**
   - Check logs: `docker logs container-name`
   - Verify port conflicts
   - Check volume permissions

2. **Service Unreachable**
   - Verify firewall rules
   - Check DNS resolution
   - Validate reverse proxy config

3. **Performance Issues**
   - Review resource allocation
   - Check for resource contention
   - Analyze metrics in Grafana

## Documentation

Each service should maintain:
- Deployment configuration
- Environment variables
- Backup procedures
- Restore procedures
- Troubleshooting guide

## Future Enhancements

- Implement GitOps with ArgoCD
- Add automated testing
- Enhance disaster recovery
- Implement blue/green deployments
