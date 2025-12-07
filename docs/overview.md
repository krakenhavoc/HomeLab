# Architecture Overview

This document provides a high-level overview of the HomeLab infrastructure architecture, key components, and network topology.

## Table of Contents

- [System Architecture](#system-architecture)
- [Infrastructure Components](#infrastructure-components)
- [Network Topology](#network-topology)
- [Technology Stack](#technology-stack)
- [Data Flow](#data-flow)
- [Related Documentation](#related-documentation)

## System Architecture

The HomeLab infrastructure is built on a layered architecture designed for flexibility, scalability, and ease of management.

```
┌─────────────────────────────────────────────────────────────┐
│                     Application Layer                        │
│  (Kubernetes Workloads, Services, Media Servers)            │
└─────────────────────────────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────┐
│                   Orchestration Layer                        │
│     (Kubernetes Cluster, Container Runtime, CNI)            │
└─────────────────────────────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────┐
│                   Virtualization Layer                       │
│            (Proxmox VE, VMs, Cloud-init)                    │
└─────────────────────────────────────────────────────────────┘
                             ↓
┌─────────────────────────────────────────────────────────────┐
│                    Infrastructure Layer                      │
│           (Physical Servers, Storage, Network)              │
└─────────────────────────────────────────────────────────────┘
```

## Infrastructure Components

### Hypervisor Platform

**Proxmox Virtual Environment (VE)**
- Type 1 hypervisor for running virtual machines
- Provides web-based management interface
- Supports cloud-init for automated VM provisioning
- Integrated backup and snapshot functionality

### Kubernetes Cluster

The current deployment includes a production-grade Kubernetes cluster:

**Master Node (Control Plane)**
- **k8s-master-1**: Single control plane node
  - Memory: 4 GB RAM
  - Runs Kubernetes control plane components (API server, scheduler, controller manager)
  - Hosts etcd datastore
  - Cloud-init automated setup

**Worker Nodes**
- **k8s-worker-2**: Worker node for application workloads
  - Memory: 4 GB RAM
  - Runs container workloads via containerd

- **k8s-worker-3**: Worker node for application workloads
  - Memory: 4 GB RAM
  - Runs container workloads via containerd

**Kubernetes Components**
- **Version**: v1.29 (latest stable)
- **Container Runtime**: Containerd (replacing deprecated Docker)
- **CNI Plugin**: Calico for pod networking and network policies
- **Service Type**: NodePort and LoadBalancer support
- **Package Management**: apt-based with version pinning

### Configuration Management

**Terraform**
- Infrastructure as Code (IaC) for VM provisioning
- Modular design with reusable components
- Module: `pve-cloudinit-vm` for Proxmox VM creation
- State management for infrastructure tracking
- CI/CD integration via GitHub Actions

**Cloud-init**
- Automated VM initialization and configuration
- Package installation and system setup
- Kubernetes component installation
- Network and security configuration
- Integration with Proxmox snippets storage

**Ansible** (Future)
- Configuration drift detection
- Application deployment automation
- System updates and patching

## Network Topology

### High-Level Network Design

```
                    Internet
                       │
                       ↓
                 ┌──────────┐
                 │ OpnSense │  (Firewall/Router)
                 │ Firewall │
                 └──────────┘
                       │
              ┌────────┴────────┐
              │                 │
         ┌─────────┐      ┌─────────┐
         │ UniFi   │      │  Core   │
         │ Switch  │──────│ Switch  │
         └─────────┘      └─────────┘
              │                 │
    ┌─────────┼─────────────────┼─────────┐
    │         │                 │         │
┌───────┐ ┌───────┐     ┌───────────┐ ┌─────┐
│ VLAN  │ │ VLAN  │     │  Proxmox  │ │ NAS │
│ 10    │ │ 20    │     │  Cluster  │ │     │
│(Mgmt) │ │(Apps) │     └───────────┘ └─────┘
└───────┘ └───────┘           │
                              │
                    ┌─────────┴──────────┐
                    │                    │
              ┌──────────┐          ┌──────────┐
              │ K8s      │          │ K8s      │
              │ Master   │          │ Workers  │
              │ (VM)     │          │ (VMs)    │
              └──────────┘          └──────────┘
```

### Network Segments

1. **Management VLAN (VLAN 10)**
   - Hypervisor management interfaces
   - Infrastructure services (DNS, DHCP)
   - Administrative access

2. **Application VLAN (VLAN 20)**
   - Kubernetes cluster nodes
   - Application services
   - Container workloads

3. **Pod Network (Calico CNI)**
   - Internal pod-to-pod communication
   - Network policy enforcement
   - Overlay network for Kubernetes

### IP Addressing

- Management Network: 10.0.10.0/24
- Application Network: 10.0.20.0/24
- Pod Network (Calico): 192.168.0.0/16 (default)
- Service Network: 10.96.0.0/12 (Kubernetes ClusterIP range)

## Technology Stack

### Infrastructure Layer

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Hypervisor | Proxmox VE 7.x+ | Virtual machine management |
| IaC | Terraform | Infrastructure provisioning |
| Config Mgmt | Cloud-init, Ansible | Automated configuration |
| Backup | Proxmox Backup Server | VM backup and recovery |

### Platform Layer

| Component | Technology | Version |
|-----------|-----------|---------|
| OS | Ubuntu 24.04 LTS | Base operating system |
| Container Runtime | Containerd | 1.6+ |
| Orchestration | Kubernetes | v1.29 |
| CNI | Calico | Latest |
| Service Mesh | Future: Istio/Linkerd | - |

### Application Layer

| Component | Technology | Purpose |
|-----------|-----------|---------|
| CI/CD | GitHub Actions | Automation pipelines |
| Monitoring | Prometheus + Grafana | Metrics and visualization |
| Logging | Future: ELK/Loki | Log aggregation |
| Service Discovery | CoreDNS | DNS within cluster |

### Network Layer

| Component | Technology | Purpose |
|-----------|-----------|---------|
| Firewall | OpnSense | Network security |
| Switching | UniFi | Network connectivity |
| VLANs | 802.1Q | Network segmentation |
| CNI | Calico | Pod networking |

## Data Flow

### VM Provisioning Flow

```
GitHub Commit → GitHub Actions → Terraform Plan → Terraform Apply
                                        ↓
                                  Proxmox API
                                        ↓
                          Create VM with Cloud-init
                                        ↓
                            Boot VM + Run Cloud-init
                                        ↓
                     Install Packages + Configure K8s
                                        ↓
                           Join Kubernetes Cluster
```

### Application Deployment Flow

```
Developer Push → Git Repository → CI/CD Pipeline
                                        ↓
                                  Build Container
                                        ↓
                               Push to Registry
                                        ↓
                              Deploy to Kubernetes
                                        ↓
                          Schedule Pods on Workers
                                        ↓
                          Expose via Service/Ingress
```

### Traffic Flow

```
External User → Internet → Firewall → Load Balancer
                                            ↓
                                  Kubernetes Service
                                            ↓
                              Pod (via Calico CNI)
                                            ↓
                                   Application
```

## Scalability Considerations

### Horizontal Scaling
- Add more Kubernetes worker nodes via Terraform
- Scale pod replicas using Kubernetes Deployments
- Load balancing across multiple pods

### Vertical Scaling
- Adjust VM memory and CPU allocations
- Configure Kubernetes resource requests/limits
- Storage expansion via Proxmox

### High Availability (Future)
- Multiple master nodes for control plane HA
- etcd cluster with 3+ members
- Load balancer for API server access
- Distributed storage solution

## Security Architecture

### Network Security
- VLAN segmentation for isolation
- Firewall rules between network segments
- Network policies in Kubernetes (Calico)
- Private networks for pod communication

### Access Control
- SSH key-based authentication
- Kubernetes RBAC for authorization
- Proxmox user permissions
- Principle of least privilege

### Secrets Management
- Kubernetes Secrets for sensitive data
- Environment variables (not in code)
- Future: HashiCorp Vault integration
- No credentials in Git repository

## Disaster Recovery

### Backup Strategy
- VM snapshots via Proxmox
- Proxmox Backup Server for scheduled backups
- etcd backup for Kubernetes state
- Configuration stored in Git (GitOps)

### Recovery Procedures
- VM restoration from Proxmox backups
- Kubernetes cluster recreation via Terraform
- Application redeployment from Git
- See [Runbook](runbook.md) for detailed procedures

## Monitoring and Observability

### Current Setup
- GitHub Actions for CI/CD monitoring
- Terraform state tracking
- Basic Proxmox metrics

### Planned Implementation
- Prometheus for metrics collection
- Grafana for visualization
- AlertManager for alerting
- Loki for log aggregation
- Distributed tracing (Jaeger)

## Related Documentation

- [Runbook](runbook.md) - Deployment procedures and operations
- [Network Setup](network-setup.md) - Detailed network configuration
- [Service Deployment](service-deployment.md) - Application deployment guides
- [Security Guidelines](security.md) - Security best practices
- [Backup Strategy](backup-strategy.md) - Backup and recovery procedures

## Configuration Files

Key configuration files in this repository:

- **Terraform**: `terraform/deployments/home-lab/main.tf`
- **Cloud-init Master**: `scripts/deployment/cloud-init/setup-k8s-master.yml`
- **Cloud-init Worker**: `scripts/deployment/cloud-init/setup-k8s-worker.yml`
- **Calico Patch**: `scripts/deployment/cloud-init/calico-patch.sh`
- **CI/CD**: `.github/workflows/terraform.yml`

---

For deployment instructions and troubleshooting, see the [Runbook](runbook.md).
