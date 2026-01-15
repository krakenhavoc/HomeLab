# Home Lab Kubernetes Cluster Deployment

Terraform deployment for a complete Kubernetes cluster on Proxmox using cloud-init.

## 📋 Overview

This deployment creates a production-ready Kubernetes v1.29 cluster with:
- **1 Master Node** - Control plane for cluster management
- **2 Worker Nodes** - Application workload execution
- **Containerd Runtime** - Container runtime (Kubernetes 1.24+ standard)
- **Calico CNI** - Pod networking and network policies
- **Cloud-init** - Automated VM provisioning and configuration

## 🏗️ Infrastructure Components

### Master Node (k8s-master-1)
- **CPU**: 2 cores
- **Memory**: 4096 MB
- **Disk**: 50 GB
- **IP**: 192.168.1.110
- **Role**: Kubernetes control plane
- **Services**: API server, scheduler, controller manager, etcd

### Worker Nodes (k8s-worker-1, k8s-worker-2)
- **CPU**: 2 cores each
- **Memory**: 4096 MB each
- **Disk**: 50 GB each
- **IPs**: 192.168.1.111, 192.168.1.112
- **Role**: Application workloads
- **Services**: kubelet, kube-proxy, containerd

## 📁 Directory Structure

```
home-lab/
├── main.tf              # Main Terraform configuration
├── variables.tf         # Input variable definitions
├── outputs.tf           # Output values
├── providers.tf         # Provider configuration
├── versions.tf          # Version constraints
├── backend.tf           # State backend configuration
├── locals.tf            # Local values and computed data
├── env/                 # Environment-specific configurations
│   └── lab/
│       └── terraform.tfvars
└── README.md            # This file
```

## 🚀 Quick Start

### Prerequisites

1. **Proxmox VE** running with API access
2. **Ubuntu 22.04 cloud image** template in Proxmox
3. **Terraform** >= 1.0 installed
4. **SSH keys** generated
5. **Network access** to Proxmox API

### Step 1: Configure Environment

Create environment file:
```bash
# .env (don't commit this)
export PM_API_URL="https://proxmox.homelab.local:8006/api2/json"
export PM_API_TOKEN_ID="terraform@pam!terraform"
export PM_API_TOKEN_SECRET="your-secret-here"
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
```

Load environment:
```bash
source .env
```

### Step 2: Review Configuration

Edit `env/lab/terraform.tfvars`:
```hcl
# Cluster Configuration
master_count = 1
worker_count = 2

# VM Resources
master_cores = 2
master_memory = 4096
worker_cores = 2
worker_memory = 4096

# Network Configuration
network_gateway = "192.168.1.1"
network_dns = "192.168.1.2"
master_ip_start = "192.168.1.110"
worker_ip_start = "192.168.1.111"
```

### Step 3: Initialize Terraform

```bash
terraform init
```

### Step 4: Plan Deployment

```bash
terraform plan -out=k8s-cluster.tfplan
```

Review the planned changes carefully.

### Step 5: Deploy Cluster

```bash
terraform apply k8s-cluster.tfplan
```

Deployment takes approximately 10-15 minutes.

### Step 6: Access Cluster

```bash
# SSH to master node
ssh root@192.168.1.110

# Check cluster status
kubectl get nodes
kubectl get pods -A

# Copy kubeconfig to local machine
scp root@192.168.1.110:/etc/kubernetes/admin.conf ~/.kube/config-homelab
export KUBECONFIG=~/.kube/config-homelab
kubectl get nodes
```

## 🔧 Configuration

### Variables

#### Required Variables
- `pm_api_url` - Proxmox API URL
- `pm_api_token_id` - Proxmox API token ID
- `pm_api_token_secret` - Proxmox API token secret
- `ssh_public_key` - SSH public key for VM access

#### Optional Variables
- `proxmox_node` - Target Proxmox node (default: "pve")
- `template_name` - Cloud-init template name (default: "ubuntu-2204-cloudinit-template")
- `master_count` - Number of master nodes (default: 1)
- `worker_count` - Number of worker nodes (default: 2)
- `master_cores` - CPU cores for master (default: 2)
- `master_memory` - Memory for master in MB (default: 4096)
- `worker_cores` - CPU cores for workers (default: 2)
- `worker_memory` - Memory for workers in MB (default: 4096)

### Outputs

The deployment provides these outputs:
```bash
# View all outputs
terraform output

# Specific outputs
terraform output master_ips
terraform output worker_ips
terraform output ssh_commands
```

## 📦 What Gets Deployed

### Kubernetes Components

**Master Node:**
- kubeadm, kubelet, kubectl
- containerd runtime
- Calico CNI
- etcd
- kube-apiserver
- kube-controller-manager
- kube-scheduler

**Worker Nodes:**
- kubeadm, kubelet, kubectl
- containerd runtime
- Calico CNI
- kube-proxy

### Cloud-init Configuration

Each node is configured with:
- System updates and essential packages
- Containerd installation and configuration
- Kubernetes repository setup
- Network configuration
- Firewall rules
- Kubernetes component installation
- Cluster initialization (master) or join (workers)

Cloud-init scripts located at: `../../scripts/deployment/cloud-init/`

## 🧪 Testing the Cluster

### Verify Node Status

```bash
kubectl get nodes -o wide
```

Expected output:
```
NAME            STATUS   ROLES           AGE   VERSION
k8s-master-1    Ready    control-plane   10m   v1.29.0
k8s-worker-1    Ready    <none>          8m    v1.29.0
k8s-worker-2    Ready    <none>          8m    v1.29.0
```

### Deploy Test Application

```bash
# Create nginx deployment
kubectl create deployment nginx --image=nginx --replicas=3

# Expose as NodePort service
kubectl expose deployment nginx --port=80 --type=NodePort

# Check deployment
kubectl get pods -o wide
kubectl get svc nginx
```

### Test Pod Networking

```bash
# Create test pods
kubectl run test-1 --image=busybox --command -- sleep 3600
kubectl run test-2 --image=busybox --command -- sleep 3600

# Test pod-to-pod connectivity
kubectl exec test-1 -- ping -c 3 $(kubectl get pod test-2 -o jsonpath='{.status.podIP}')
```

## 📊 Monitoring

### Check Cluster Health

```bash
# Component status
kubectl get componentstatuses

# Cluster info
kubectl cluster-info

# System pods
kubectl get pods -n kube-system
```

### Resource Usage

```bash
# Node resources
kubectl top nodes

# Pod resources
kubectl top pods -A
```

## 🔄 Maintenance

### Scale Workers

Edit `terraform.tfvars`:
```hcl
worker_count = 3  # Scale from 2 to 3
```

Apply changes:
```bash
terraform plan
terraform apply
```

### Upgrade Kubernetes

1. Update cloud-init scripts with new version
2. Create new template with updated scripts
3. Replace nodes one at a time:
   ```bash
   # Drain node
   kubectl drain k8s-worker-1 --ignore-daemonsets
   
   # Recreate with Terraform
   terraform taint module.worker[0]
   terraform apply
   
   # Verify new node
   kubectl get nodes
   ```

### Backup Configuration

```bash
# Backup etcd (on master)
ETCDCTL_API=3 etcdctl snapshot save /backup/etcd-snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Backup kubeconfig
kubectl config view --raw > /backup/admin.conf
```

## 🐛 Troubleshooting

### Nodes Not Ready

```bash
# Check node status
kubectl describe node <node-name>

# Check kubelet logs
ssh root@<node-ip>
journalctl -u kubelet -f

# Check containerd
systemctl status containerd
```

### Pods Not Starting

```bash
# Check pod status
kubectl describe pod <pod-name>

# Check pod logs
kubectl logs <pod-name>

# Check events
kubectl get events --sort-by='.lastTimestamp'
```

### Network Issues

```bash
# Check Calico pods
kubectl get pods -n kube-system | grep calico

# Check CNI configuration
ls -la /etc/cni/net.d/

# Verify pod networking
kubectl run test --image=busybox --rm -it -- sh
# Inside pod:
nslookup kubernetes.default
```

### Terraform Issues

```bash
# Refresh state
terraform refresh

# View state
terraform state list

# Re-create specific resource
terraform taint <resource>
terraform apply
```

## 🔐 Security

### Best Practices

- SSH keys only (no password authentication)
- Firewall rules enabled on all nodes
- Network policies for pod security
- RBAC configured
- Regular security updates
- Secrets encrypted at rest

### Hardening Steps

```bash
# Enable audit logging
# Edit /etc/kubernetes/manifests/kube-apiserver.yaml

# Apply network policies
kubectl apply -f network-policies/

# Scan for vulnerabilities
kubectl kube-bench run
```

## 📚 Additional Resources

### Related Documentation
- [Cloud-init Scripts](../../scripts/deployment/cloud-init/README.md)
- [Terraform Modules](../../modules/README.md)
- [Main Documentation](../../../docs/README.md)

### External Links
- [Kubernetes Documentation](https://kubernetes.io/docs/)
- [Calico Documentation](https://docs.projectcalico.org/)
- [Containerd Documentation](https://containerd.io/docs/)

## 🤝 Contributing

To improve this deployment:

1. Test changes in a separate environment
2. Update documentation
3. Follow Terraform best practices
4. Validate with `terraform validate` and `tfsec`
5. Submit pull request with detailed description

## 📝 Changelog

### Version 0.1 (January 2026)
- Initial Kubernetes v1.29 cluster deployment
- Cloud-init based provisioning
- Calico CNI integration
- Containerd runtime
- 1 master + 2 worker configuration

---

**Maintained by**: HomeLab Team  
**Last Updated**: January 2026  
**Kubernetes Version**: v1.29  
**Terraform Version**: >= 1.0
