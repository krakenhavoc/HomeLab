# HomeLab Infrastructure Portfolio

[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Terraform](https://img.shields.io/badge/Terraform-1.0+-623CE4?logo=terraform)](terraform/)
[![Kubernetes](https://img.shields.io/badge/Kubernetes-v1.29-326CE5?logo=kubernetes)](scripts/deployment/cloud-init/)
[![Pre-commit](https://img.shields.io/badge/pre--commit-enabled-brightgreen?logo=pre-commit)](.pre-commit-config.yaml)

Welcome to my HomeLab infrastructure repository! This repository showcases my personal homelab setup, infrastructure automation, and technical capabilities.

## 🏠 Overview

This repository contains documentation, diagrams, and code for my homelab environment. It demonstrates my skills in:
- Network design and architecture
- Infrastructure as Code (IaC) using Terraform
- Configuration management with Ansible
- Kubernetes cluster deployment and orchestration
- Cloud-init automated provisioning
- Automation and scripting
- System administration and DevOps practices

## 📰 Recent Changes

### Kubernetes Cluster Deployment (v0.1)
The latest updates include a full Kubernetes cluster deployment using Terraform and cloud-init:
- **Kubernetes v1.29** cluster with one master and two worker nodes
- **Containerd** as the container runtime (following Kubernetes 1.24+ best practices)
- **Calico** CNI for pod networking
- Automated provisioning via **cloud-init** configuration
- Terraform modules for VM deployment on Proxmox
- CI/CD workflows for infrastructure validation

## 📁 Repository Structure

```
HomeLab/
├── .github/
│   ├── workflows/               # GitHub Actions CI/CD pipelines
│   └── ISSUE_TEMPLATE/          # Issue templates for bug reports and features
├── docs/                        # Documentation and guides
│   ├── overview.md              # Architecture overview
│   ├── runbook.md               # Deployment and operations guide
│   ├── network-setup.md         # Network configuration
│   ├── service-deployment.md    # Service deployment guides
│   ├── backup-strategy.md       # Backup procedures
│   └── security.md              # Security guidelines
├── diagrams/                    # Network and infrastructure diagrams
│   ├── network/                 # Network topology diagrams
│   └── infrastructure/          # Infrastructure architecture diagrams
├── terraform/                   # Infrastructure as Code (Terraform)
│   ├── deployments/             # Deployment configurations
│   │   ├── lab/                 # Lab VMs (openclaw, pwnbox, cmd_and_ctrl, win11)
│   │   ├── frontends/           # Private frontends (RedLib)
│   │   ├── gh-runner/           # Self-hosted GitHub Actions runners
│   │   ├── nfs/                 # NFS server
│   │   ├── plex/                # Plex media host
│   │   └── shared/              # Shared images and LXC templates
│   └── modules/                 # Reusable Terraform modules
│       └── compute/             # Compute resource modules
│           └── pm-cloudinit-vm/   # Proxmox cloud-init VM module
├── ansible/                     # Configuration management
│   ├── playbooks/               # Ansible playbooks
│   ├── roles/                   # Custom roles
│   └── inventory/               # Inventory files
└── scripts/                     # Utility scripts and automation
    ├── backup/                  # Backup scripts
    ├── monitoring/              # Monitoring scripts
    └── deployment/              # Deployment automation
        └── cloud-init/          # Cloud-init configurations for K8s
```

## 🔧 Technologies Used

- **Virtualization**: Proxmox, Docker, Kubernetes
- **Infrastructure as Code**: Terraform
- **Configuration Management**: Ansible
- **Networking**: VLANs, OpnSense, UniFi
- **Monitoring**: Prometheus, Grafana
- **Storage**: NAS, ZFS
- **Scripting**: Bash, Python

## 🚀 Getting Started

### Prerequisites

- **Terraform** >= 1.14
- **Ansible** >= 2.9
- **Python** >= 3.8
- **Proxmox VE** (for infrastructure deployment)
- **kubectl** (for Kubernetes cluster management)
- Docker (optional, for local testing)

### Quick Start

1. **Clone this repository:**
   ```bash
   git clone https://github.com/krakenhavoc/HomeLab.git
   cd HomeLab
   ```

2. **Review the documentation:**
   - Start with [Architecture Overview](docs/overview.md)
   - Follow the [Runbook](docs/runbook.md) for deployment steps

3. **Plan a deployment locally:**
   ```bash
   # Pick a deployment under terraform/deployments/
   cd terraform/deployments/lab

   # Initialize Terraform (state lives in Terraform Cloud, org LabXPIO)
   terraform init

   # Review planned changes against the environment's tfvars
   terraform plan -var-file=env/lab/terraform.tfvars
   ```

4. **Apply through CI, not locally:**

   Each deployment has a workflow that plans on pull requests and applies only
   on a merge to `main` (see `.github/workflows/`). Applying by hand bypasses
   that gate — it is how the production `cmd_and_ctrl` VM was destroyed on
   2026-09-10. Use `terraform-replace.yaml` for a deliberate single-resource
   rebuild.

### Docker Example

For local testing and development:
```bash
# Run containerized applications
docker run -d -p 8080:80 nginx
```

### Kubernetes Example

Deploy an application to your cluster:
```bash
# Create a deployment
kubectl create deployment nginx --image=nginx

# Expose the deployment
kubectl expose deployment nginx --port=80 --type=NodePort

# Check the service
kubectl get services
```

## 📊 Infrastructure Components

### Network Infrastructure
- Core network topology with VLAN segmentation
- Firewall rules and security policies (OpnSense)
- DNS and DHCP configuration
- UniFi network management

### Compute Resources
- **Proxmox VE** hypervisor for virtualization
- **Kubernetes cluster** (1 master + 2 worker nodes)
  - Containerd runtime
  - Calico CNI networking
  - Cloud-init automated provisioning
- Virtual machine templates and configurations
- Resource allocation and auto-scaling

### Services
- **Kubernetes workloads** (microservices, applications)
- Media servers (Plex, Jellyfin)
- Development environments
- **Monitoring stack** (Prometheus, Grafana)
- Logging and observability
- Backup and disaster recovery solutions

## 📖 Documentation

Detailed documentation for each component can be found in the `docs/` directory:
- [Architecture Overview](docs/overview.md) - High-level system architecture and topology
- [Runbook](docs/runbook.md) - Deployment procedures and troubleshooting
- [Network Setup](docs/network-setup.md) - Network configuration details
- [Service Deployment](docs/service-deployment.md) - Service deployment guides
- [Backup Strategy](docs/backup-strategy.md) - Backup procedures and recovery
- [Security Guidelines](docs/security.md) - Security best practices

## 🌐 Supported Platforms

- **Hypervisor**: Proxmox VE 7.x+
- **Operating Systems**: Ubuntu 22.04 LTS (cloud-init images)
- **Container Runtime**: Containerd 1.6+
- **Kubernetes**: v1.29
- **Terraform**: 1.0+
- **Ansible**: 2.9+

## 💻 Language Composition

- **HCL** (Terraform) - Infrastructure as Code
- **YAML** - Cloud-init configurations, Kubernetes manifests, Ansible playbooks
- **Bash** - Automation scripts
- **Python** - Utility scripts and tooling
- **Markdown** - Documentation

## 🔐 Security & Best Practices

- Secrets are managed using environment variables and secure vaults
- No sensitive credentials are stored in this repository
- Infrastructure follows the principle of least privilege
- Regular security updates and patch management

## 📈 Future Enhancements

- [ ] Implement GitOps workflows (ArgoCD/Flux)
- [ ] Expand CI/CD pipelines for automated testing
- [ ] Add Helm charts for application deployments
- [ ] Enhance monitoring with custom dashboards
- [ ] Implement log aggregation (ELK/Loki)
- [ ] Automated disaster recovery procedures
- [ ] Service mesh integration (Istio/Linkerd)

## 🤝 Contributing

We welcome contributions! Please see our [Contributing Guide](CONTRIBUTING.md) for details on:
- Code of conduct
- Development workflow
- Pull request process
- Code style guidelines

To report bugs or request features, please use our [issue templates](.github/ISSUE_TEMPLATE/).

## 📋 Changelog

See [CHANGELOG.md](CHANGELOG.md) for a detailed history of changes and releases.

## 📝 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

This project is for portfolio and educational purposes.

## 👤 Maintainer

**krakenhavoc**
- GitHub: [@krakenhavoc](https://github.com/krakenhavoc)

## 📧 Contact

For questions, suggestions, or collaboration opportunities:
- Open an [issue](https://github.com/krakenhavoc/HomeLab/issues)
- Start a [discussion](https://github.com/krakenhavoc/HomeLab/discussions)
- Reach out through GitHub

---

⭐ **Star this repository** if you find it helpful or interesting!

*This repository is actively maintained and regularly updated with new features and improvements.*
