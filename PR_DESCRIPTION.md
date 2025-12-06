# Kubernetes Cluster Deployment with Cloud-Init and Terraform

## 🎯 Summary

This PR introduces automated Kubernetes cluster deployment capabilities to the HomeLab infrastructure. It implements a complete Kubernetes v1.29 cluster setup using cloud-init automation and Terraform modules, enabling rapid deployment of master and worker nodes on Proxmox VE.

## 🚀 Key Features

### 1. Cloud-Init Automation Scripts
- **Master Node Setup** (`setup-k8s-master.yml`): Automated initialization of Kubernetes control plane
  - Kubernetes v1.29 installation with kubeadm, kubelet, and kubectl
  - Containerd as the CRI (Container Runtime Interface)
  - Calico CNI plugin with custom CIDR configuration (10.244.0.0/16)
  - Automatic cluster initialization and kubeconfig setup
  - Join command generation for worker nodes

- **Worker Node Setup** (`setup-k8s-worker.yml`): Streamlined worker node configuration
  - Kubernetes components installation
  - Containerd runtime setup
  - Ready to join the cluster (requires join command from master)

- **Calico Network Plugin Patch** (`calico-patch.sh`): Custom script to configure Calico
  - Automatically downloads Calico manifest
  - Injects correct pod network CIDR (10.244.0.0/16)
  - Applies the patched configuration to the cluster

### 2. Terraform Module for Proxmox Cloud-Init VMs
Created a reusable Terraform module (`pve-cloudinit-vm`) that:
- Abstracts VM creation with cloud-init configuration
- Provides sensible defaults with full customization options
- Supports UEFI boot with OVMF BIOS
- Enables QEMU guest agent by default
- Configurable resources (CPU, memory, disk)
- Flexible cloud-init user data injection

**Module Variables:**
- `vm_name`: VM identifier (required)
- `pve_node`: Target Proxmox node (default: "pve")
- `memory_bytes`: RAM allocation (default: 2048MB)
- `cpu_cores`: CPU core count (default: 2)
- `ci_user_data`: Cloud-init configuration path
- `os_disk_size`: Disk size (default: 15G)
- And more...

### 3. Simplified Deployment Configuration
Updated `terraform/deployments/home-lab/main.tf` to use the new module:
- **Kubernetes Master**: Single master node (k8s-master-1) with 4GB RAM
- **Kubernetes Workers**: Two worker nodes (k8s-worker-2, k8s-worker-3) with 4GB RAM each
- Reduced configuration complexity from ~56 lines to ~18 lines
- Improved maintainability and scalability

## 📋 Changes Overview

### New Files
```
scripts/deployment/cloud-init/
├── calico-patch.sh              # Calico CNI configuration script
├── setup-k8s-master.yml         # Master node cloud-init config
└── setup-k8s-worker.yml         # Worker node cloud-init config

terraform/modules/compute/pve-cloudinit-vm/
├── main.tf                      # Module resource definitions
├── variables.tf                 # Module input variables
└── versions.tf                  # Terraform version constraints
```

### Modified Files
```
terraform/deployments/home-lab/main.tf    # Refactored to use new module
```

### Statistics
- **7 files changed**
- **320 insertions** (+)
- **52 deletions** (-)
- **Net change**: +268 lines

## 🔧 Technical Details

### Kubernetes Configuration
- **Version**: v1.29 (stable)
- **Container Runtime**: Containerd (Docker-free)
- **Network Plugin**: Calico
- **Pod Network CIDR**: 10.244.0.0/16
- **Service CIDR**: Default (10.96.0.0/12)

### Infrastructure Components
- **Base OS**: Ubuntu Noble (24.04 LTS)
- **Hypervisor**: Proxmox Virtual Environment
- **IaC Tool**: Terraform
- **Automation**: Cloud-init

### Key Design Decisions
1. **Containerd over Docker**: Kubernetes 1.24+ deprecated DockerShim, making containerd the preferred runtime
2. **Calico CNI**: Robust network policy support and performance
3. **Cloud-init**: Declarative, idempotent VM configuration
4. **Terraform Modules**: DRY principle, reusability across environments
5. **SystemdCgroup**: Better integration with systemd-based systems

## 🔐 Security Considerations

- Passwords managed via Terraform variables (external to repository)
- QEMU guest agent enabled for improved VM management
- NFS support included for persistent storage
- Kernel networking parameters optimized for container workloads
- Automatic package updates enabled

## 📚 Prerequisites

Before deploying this infrastructure:
1. Proxmox VE with Ubuntu Noble template (`ubuntu-noble-template`)
2. Terraform with Proxmox provider configured
3. Cloud-init snippets stored in Proxmox local storage
4. Network connectivity for package downloads
5. Sufficient resources (minimum 12GB RAM total for 3 nodes)

## 🚦 Deployment Steps

1. Copy cloud-init files to Proxmox snippets directory:
   ```bash
   # On Proxmox host
   cp setup-k8s-master.yml /var/lib/vz/snippets/setup_k8s_master.yml
   cp setup-k8s-worker.yml /var/lib/vz/snippets/setup_k8s_worker.yml
   ```

2. Deploy infrastructure:
   ```bash
   cd terraform/deployments/home-lab
   terraform init
   terraform plan
   terraform apply
   ```

3. After master node initialization, retrieve join command:
   ```bash
   ssh root@k8s-master-1 "cat /root/kubeadm_join_command.sh"
   ```

4. Update worker cloud-init config with join command and redeploy workers

## 🧪 Testing

The deployment can be verified by:
1. Checking VM creation in Proxmox web interface
2. SSH access to nodes
3. Kubernetes cluster status: `kubectl get nodes`
4. Pod network functionality: `kubectl get pods -A`
5. Calico deployment: `kubectl get pods -n kube-system -l k8s-app=calico-node`

## 🎯 Future Enhancements

This foundation enables:
- [ ] High-availability control plane (multiple masters)
- [ ] Persistent storage with NFS or Ceph
- [ ] Ingress controller deployment
- [ ] Monitoring with Prometheus/Grafana
- [ ] GitOps workflows with ArgoCD/Flux
- [ ] Automated certificate management
- [ ] Service mesh integration (Istio/Linkerd)

## 📝 Documentation Impact

- Aligns with "Expand Kubernetes deployment" goal from README
- Demonstrates Infrastructure as Code best practices
- Showcases container orchestration capabilities
- Provides reusable Terraform patterns

## ✅ Checklist

- [x] Code follows infrastructure as code best practices
- [x] Cloud-init configurations are idempotent
- [x] Terraform module is reusable and well-documented
- [x] Secrets are externalized (not in repository)
- [x] Network configuration is properly documented
- [x] Resource requirements are specified

## 🤝 Contributing

This is a portfolio project demonstrating homelab infrastructure automation. For questions or suggestions, please open an issue.

---

**Merge Impact**: This PR adds significant functionality without breaking existing infrastructure. The changes are additive and can be deployed independently.
