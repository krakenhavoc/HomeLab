# Operations Runbook

This runbook provides step-by-step procedures for deploying, operating, and troubleshooting the HomeLab infrastructure.

## Table of Contents

- [Prerequisites](#prerequisites)
- [Initial Setup](#initial-setup)
- [Deployment Procedures](#deployment-procedures)
- [Required Secrets and Variables](#required-secrets-and-variables)
- [Common Operations](#common-operations)
- [Troubleshooting](#troubleshooting)
- [Maintenance Tasks](#maintenance-tasks)
- [Emergency Procedures](#emergency-procedures)

## Prerequisites

### Required Software

Ensure the following tools are installed on your workstation:

```bash
# Terraform (Infrastructure as Code)
terraform --version  # Should be >= 1.0

# kubectl (Kubernetes CLI)
kubectl version --client  # Should be >= 1.29

# SSH client
ssh -V

# Git
git --version
```

### Required Access

- Proxmox VE admin credentials
- SSH access to Proxmox host
- GitHub repository access
- Network access to management VLAN

### Proxmox Requirements

- Proxmox VE 7.x or later installed and configured
- Storage pool configured (e.g., `local-lvm` for VM disks)
- Snippets storage configured (e.g., `local:snippets`)
- Ubuntu 22.04 cloud-init template created
- Network bridge configured (e.g., `vmbr0`)

## Initial Setup

### 1. Clone Repository

```bash
git clone https://github.com/krakenhavoc/HomeLab.git
cd HomeLab
```

### 2. Configure Terraform Backend

Edit `terraform/deployments/home-lab/backend.tf` if using remote state:

```hcl
terraform {
  backend "local" {
    path = "terraform.tfstate"
  }
  # Or use remote backend:
  # backend "s3" {
  #   bucket = "my-terraform-state"
  #   key    = "homelab/terraform.tfstate"
  #   region = "us-east-1"
  # }
}
```

### 3. Configure Terraform Variables

Create `terraform/deployments/home-lab/terraform.tfvars`:

```hcl
# Proxmox connection settings
proxmox_api_url = "https://proxmox.example.com:8006/api2/json"
proxmox_node    = "pve"

# VM root password (use environment variable or secure vault)
cloudinit-example_root-password = "your-secure-password"

# Network settings
vm_network_bridge = "vmbr0"
vm_network_vlan   = 20
```

**Security Note**: Never commit `terraform.tfvars` to Git. Use environment variables or a secrets manager.

### 4. Prepare Cloud-init Snippets

Upload cloud-init configurations to Proxmox snippets storage:

```bash
# SSH to Proxmox host
ssh root@proxmox.example.com

# Navigate to snippets directory
cd /var/lib/vz/snippets/

# Copy cloud-init files (or upload via web UI)
# Files needed:
# - setup_k8s_master.yml
# - setup_k8s_worker.yml
# - calico-patch.sh
```

Alternatively, use Proxmox web UI:
1. Go to Datacenter → Storage → local
2. Click "Content" → "Snippets"
3. Upload the files from `scripts/deployment/cloud-init/`

## Deployment Procedures

### Deploy Kubernetes Cluster

#### Step 1: Initialize Terraform

```bash
cd terraform/deployments/home-lab

# Initialize Terraform (download providers, modules)
terraform init

# Validate configuration
terraform validate
```

#### Step 2: Plan Infrastructure Changes

```bash
# Generate and review execution plan
terraform plan

# Save plan to file for review
terraform plan -out=tfplan

# Review the plan
terraform show tfplan
```

Expected output:
- 1 master node VM to be created
- 2 worker node VMs to be created
- Total: 3 resources to add

#### Step 3: Apply Infrastructure

```bash
# Apply the planned changes
terraform apply

# Or apply saved plan
terraform apply tfplan
```

This will:
1. Create VMs in Proxmox
2. Configure cloud-init
3. Boot VMs
4. Install Kubernetes components
5. Initialize the cluster

**Wait Time**: Initial deployment takes 5-10 minutes for VMs to boot and complete cloud-init.

#### Step 4: Verify Deployment

```bash
# SSH to master node
ssh root@k8s-master-1

# Check node status
kubectl get nodes

# Expected output:
# NAME           STATUS   ROLES           AGE   VERSION
# k8s-master-1   Ready    control-plane   5m    v1.29.x
# k8s-worker-2   Ready    <none>          4m    v1.29.x
# k8s-worker-3   Ready    <none>          4m    v1.29.x

# Check all pods
kubectl get pods -A

# Check Calico networking
kubectl get pods -n kube-system | grep calico
```

### Deploy Additional Applications

#### Deploy a Test Application

```bash
# Create deployment
kubectl create deployment nginx --image=nginx:latest --replicas=3

# Expose the deployment
kubectl expose deployment nginx --port=80 --type=NodePort

# Get service details
kubectl get svc nginx

# Test access
curl http://<worker-node-ip>:<node-port>
```

#### Deploy Using Manifests

```bash
# Apply manifest
kubectl apply -f deployment.yaml

# Check status
kubectl rollout status deployment/myapp
```

## Required Secrets and Variables

### Environment Variables

Set these environment variables before running Terraform:

```bash
# Proxmox credentials
export PROXMOX_VE_USERNAME="root@pam"
export PROXMOX_VE_PASSWORD="your-password"

# Or use API token (recommended)
export PROXMOX_VE_API_TOKEN="user@realm!tokenname=uuid"

# VM root password
export TF_VAR_cloudinit_root_password="secure-password"
```

### Terraform Variables

| Variable | Description | Required | Default |
|----------|-------------|----------|---------|
| `proxmox_api_url` | Proxmox API endpoint | Yes | - |
| `proxmox_node` | Target Proxmox node | Yes | - |
| `cloudinit-example_root-password` | VM root password | Yes | - |
| `vm_network_bridge` | Network bridge | No | `vmbr0` |
| `vm_network_vlan` | VLAN tag | No | `20` |
| `vm_memory` | Memory allocation (MB) | No | `4096` |

### Kubernetes Secrets

Create secrets for applications:

```bash
# Create secret from literal
kubectl create secret generic db-password \
  --from-literal=password='myP@ssw0rd'

# Create secret from file
kubectl create secret generic tls-cert \
  --from-file=tls.crt=./cert.crt \
  --from-file=tls.key=./cert.key

# Create docker registry secret
kubectl create secret docker-registry regcred \
  --docker-server=registry.example.com \
  --docker-username=user \
  --docker-password=password
```

## Common Operations

### Scale Worker Nodes

To add more worker nodes, edit `terraform/deployments/home-lab/main.tf`:

```hcl
module "k8s_workers" {
  source   = "../../modules/compute/pve-cloudinit-vm"
  for_each = toset(["2", "3", "4"])  # Add "4" for new node

  vm_name      = "k8s-worker-${each.key}"
  memory_bytes = 4096
  ci_user_data = "vendor=local:snippets/setup_k8s_worker.yml"
  cloudinit-example_root-password = var.cloudinit-example_root-password
}
```

Then apply:

```bash
terraform plan
terraform apply
```

### Update Kubernetes

```bash
# SSH to master node
ssh root@k8s-master-1

# Check current version
kubectl version

# Update kubeadm
apt-mark unhold kubeadm
apt-get update && apt-get install -y kubeadm=1.29.x-00
apt-mark hold kubeadm

# Plan upgrade
kubeadm upgrade plan

# Apply upgrade
kubeadm upgrade apply v1.29.x

# Drain node
kubectl drain k8s-master-1 --ignore-daemonsets

# Update kubelet and kubectl
apt-mark unhold kubelet kubectl
apt-get update && apt-get install -y kubelet=1.29.x-00 kubectl=1.29.x-00
apt-mark hold kubelet kubectl

# Restart kubelet
systemctl daemon-reload
systemctl restart kubelet

# Uncordon node
kubectl uncordon k8s-master-1
```

### Backup Cluster State

```bash
# Backup etcd
ETCDCTL_API=3 etcdctl snapshot save snapshot.db \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/kubernetes/pki/etcd/ca.crt \
  --cert=/etc/kubernetes/pki/etcd/server.crt \
  --key=/etc/kubernetes/pki/etcd/server.key

# Verify snapshot
ETCDCTL_API=3 etcdctl snapshot status snapshot.db

# Backup important configs
tar -czf k8s-configs-$(date +%Y%m%d).tar.gz \
  /etc/kubernetes \
  ~/.kube/config
```

### Restore from Backup

```bash
# Stop kube-apiserver
mv /etc/kubernetes/manifests/kube-apiserver.yaml ~

# Restore etcd
ETCDCTL_API=3 etcdctl snapshot restore snapshot.db \
  --data-dir=/var/lib/etcd-restore

# Update etcd data directory
# Edit /etc/kubernetes/manifests/etcd.yaml

# Restart kube-apiserver
mv ~/kube-apiserver.yaml /etc/kubernetes/manifests/
```

### Check Cluster Health

```bash
# Node status
kubectl get nodes -o wide

# Component status
kubectl get cs

# Pod health across all namespaces
kubectl get pods -A

# Events (recent issues)
kubectl get events -A --sort-by='.lastTimestamp'

# Resource usage
kubectl top nodes
kubectl top pods -A
```

### View Logs

```bash
# Pod logs
kubectl logs <pod-name> -n <namespace>

# Previous pod logs (after crash)
kubectl logs <pod-name> -n <namespace> --previous

# Follow logs
kubectl logs -f <pod-name> -n <namespace>

# Logs from all containers in pod
kubectl logs <pod-name> -n <namespace> --all-containers

# System logs on node
ssh root@k8s-master-1
journalctl -u kubelet -f
```

## Troubleshooting

### Pods Not Starting

**Symptom**: Pods stuck in `Pending` or `ContainerCreating` state

```bash
# Describe pod for events
kubectl describe pod <pod-name> -n <namespace>

# Check node resources
kubectl describe nodes

# Check pod scheduling
kubectl get events -n <namespace>
```

**Common Causes**:
- Insufficient resources (CPU/memory)
- Image pull errors
- Volume mount issues
- Node selectors/taints

### Networking Issues

**Symptom**: Pods cannot communicate or reach external services

```bash
# Check Calico pods
kubectl get pods -n kube-system | grep calico

# Test pod-to-pod connectivity
kubectl run -it --rm debug --image=busybox --restart=Never -- sh
# Then inside pod:
ping <other-pod-ip>

# Check CNI configuration
ssh root@k8s-master-1
cat /etc/cni/net.d/10-calico.conflist

# Check IP tables
iptables -L -n -v
```

**Common Fixes**:
- Restart Calico pods: `kubectl delete pods -n kube-system -l k8s-app=calico-node`
- Verify network policies
- Check firewall rules

### Node Not Ready

**Symptom**: Node shows `NotReady` status

```bash
# Check node status
kubectl describe node <node-name>

# SSH to node and check kubelet
ssh root@<node-name>
systemctl status kubelet
journalctl -u kubelet -n 50

# Check container runtime
systemctl status containerd
ctr version
```

**Common Fixes**:
- Restart kubelet: `systemctl restart kubelet`
- Check disk space: `df -h`
- Verify containerd: `systemctl restart containerd`

### Terraform Apply Failures

**Symptom**: Terraform apply fails or times out

```bash
# Enable debug logging
export TF_LOG=DEBUG
export TF_LOG_PATH=terraform.log

# Re-run apply
terraform apply

# Check Proxmox logs
ssh root@proxmox.example.com
tail -f /var/log/pve/tasks/active
```

**Common Issues**:
- Proxmox API connectivity
- Insufficient resources
- Storage issues
- Template not found

### Cloud-init Not Running

**Symptom**: VMs created but Kubernetes not installed

```bash
# SSH to VM
ssh root@k8s-master-1

# Check cloud-init status
cloud-init status

# View cloud-init logs
cat /var/log/cloud-init.log
cat /var/log/cloud-init-output.log

# Re-run cloud-init (testing only)
cloud-init clean
cloud-init init
```

## Maintenance Tasks

### Weekly Tasks

```bash
# Check cluster health
kubectl get nodes
kubectl get pods -A

# Review events
kubectl get events -A --sort-by='.lastTimestamp'

# Check resource usage
kubectl top nodes
kubectl top pods -A
```

### Monthly Tasks

```bash
# Update system packages
ssh root@k8s-master-1
apt-get update
apt-get upgrade -y

# Review security updates
apt list --upgradable

# Backup etcd
# (See backup procedures above)

# Clean up old resources
kubectl delete pods --field-selector status.phase=Succeeded -A
kubectl delete pods --field-selector status.phase=Failed -A
```

### Quarterly Tasks

- Review and update Kubernetes version
- Audit security policies
- Update documentation
- Test disaster recovery procedures
- Review resource quotas and limits

## Emergency Procedures

### Complete Cluster Failure

1. **Assess the situation**
   ```bash
   # Check all nodes
   ping k8s-master-1
   ping k8s-worker-2
   ping k8s-worker-3
   ```

2. **Attempt recovery**
   ```bash
   # Try restarting services
   ssh root@k8s-master-1
   systemctl restart kubelet
   systemctl restart containerd
   ```

3. **Restore from backup** (if needed)
   - Follow backup restoration procedures
   - Redeploy from Terraform if VMs are corrupted

4. **Rebuild cluster** (last resort)
   ```bash
   # Destroy existing infrastructure
   terraform destroy
   
   # Redeploy
   terraform apply
   ```

### Security Incident

1. **Isolate affected components**
   ```bash
   # Cordon node
   kubectl cordon <node-name>
   
   # Delete compromised pods
   kubectl delete pod <pod-name> -n <namespace>
   ```

2. **Collect evidence**
   ```bash
   # Save logs
   kubectl logs <pod-name> -n <namespace> > incident-logs.txt
   
   # Export node data
   kubectl get nodes -o yaml > nodes-state.yaml
   ```

3. **Rotate credentials**
   - Update all secrets
   - Regenerate certificates
   - Change passwords

### Data Loss Prevention

- Always maintain recent backups
- Use version control for all configurations
- Document all manual changes
- Test recovery procedures regularly

---

For architectural details, see [Architecture Overview](overview.md).
For security guidelines, see [Security](security.md).
