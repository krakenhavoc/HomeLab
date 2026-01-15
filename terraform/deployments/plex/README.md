# Plex Media Server Deployment

Terraform deployment for Plex Media Server on Proxmox using cloud-init.

## 📋 Overview

This deployment creates a dedicated VM for Plex Media Server with:
- **Ubuntu 22.04 LTS** - Base operating system
- **Plex Media Server** - Latest stable version
- **Cloud-init** - Automated provisioning
- **Storage mounts** - For media libraries
- **Network configuration** - Optimized for streaming

## 🏗️ Infrastructure Components

### Plex Server VM
- **CPU**: 4 cores (recommended for transcoding)
- **Memory**: 8192 MB (8 GB)
- **Disk**: 100 GB (OS and Plex data)
- **IP**: 192.168.10.50 (configurable)
- **Network**: Server VLAN (VLAN 10)
- **Storage**: Additional mounts for media

## 📁 Directory Structure

```
plex/
├── main.tf              # Main Terraform configuration
├── variables.tf         # Input variable definitions
├── outputs.tf           # Output values (optional)
├── providers.tf         # Provider configuration
├── versions.tf          # Version constraints
├── backend.tf           # State backend configuration
├── env/                 # Environment-specific configurations
│   └── plex-dev/
│       └── terraform.tfvars
└── README.md            # This file
```

## 🚀 Quick Start

### Prerequisites

1. **Proxmox VE** with API access
2. **Ubuntu 22.04 cloud image** template
3. **Terraform** >= 1.0
4. **SSH keys** generated
5. **Media storage** available (NFS/CIFS share or local storage)
6. **Plex account** for server setup

### Step 1: Configure Environment

```bash
# .env (don't commit)
export PM_API_URL="https://proxmox.homelab.local:8006/api2/json"
export PM_API_TOKEN_ID="terraform@pam!terraform"
export PM_API_TOKEN_SECRET="your-secret-here"
export TF_VAR_ssh_public_key="$(cat ~/.ssh/id_ed25519.pub)"
```

Load environment:
```bash
source .env
```

### Step 2: Configure Variables

Edit `env/plex-dev/terraform.tfvars`:
```hcl
# VM Configuration
vm_name = "plex-server"
cpu_cores = 4
memory_mb = 8192
disk_size_gb = 100

# Network Configuration
vm_ip = "192.168.10.50"
gateway = "192.168.10.1"
dns_server = "192.168.1.2"

# Storage Configuration
media_nfs_server = "192.168.10.50"
media_nfs_path = "/mnt/media"
```

### Step 3: Deploy

```bash
# Initialize
terraform init

# Plan
terraform plan -out=plex.tfplan

# Apply
terraform apply plex.tfplan
```

Deployment takes 5-10 minutes.

### Step 4: Access Plex

1. **Web Interface**: http://192.168.10.50:32400/web
2. **First-time setup**: Sign in with Plex account
3. **Add libraries**: Configure media library paths
4. **Port forwarding**: Configure for remote access (optional)

## 🔧 Configuration

### Variables

#### Required Variables
```hcl
pm_api_url              # Proxmox API URL
pm_api_token_id         # Proxmox API token ID
pm_api_token_secret     # Proxmox API token secret
ssh_public_key          # SSH public key for access
```

#### Optional Variables
```hcl
proxmox_node = "pve"                    # Proxmox node name
template_name = "ubuntu-2204-template"  # Template to clone
vm_name = "plex-server"                 # VM name
cpu_cores = 4                           # CPU cores
memory_mb = 8192                        # Memory in MB
disk_size_gb = 100                      # Disk size
vm_ip = "192.168.10.50"                # Static IP
vlan_tag = 10                           # VLAN ID
```

### Cloud-init Configuration

The cloud-init script (`../../scripts/deployment/cloud-init/plex/setup-plex-host.yaml`) handles:
- System updates
- Plex repository configuration
- Plex Media Server installation
- Network configuration
- Storage mount configuration
- Service enablement

## 📦 Post-Deployment Setup

### 1. Access Plex Web Interface

```bash
# Open browser
http://<plex-ip>:32400/web

# Or use SSH tunnel for first-time setup
ssh -L 8888:localhost:32400 root@<plex-ip>
# Then access: http://localhost:8888/web
```

### 2. Configure Media Libraries

1. Sign in to Plex
2. Click "Add Library"
3. Select library type (Movies, TV Shows, Music, etc.)
4. Add media folder paths
5. Configure library settings
6. Scan media files

### 3. Configure Remote Access (Optional)

```bash
# Enable remote access in Plex settings
Settings > Remote Access > Enable Remote Access

# Configure port forwarding on router
External Port: 32400 TCP -> Internal IP: <plex-ip>:32400

# Verify remote access works
https://app.plex.tv
```

### 4. Mount Additional Storage

If using NFS/CIFS for media:

```bash
# SSH to Plex server
ssh root@<plex-ip>

# Create mount point
mkdir -p /mnt/media

# Add to /etc/fstab for NFS
echo "192.168.10.50:/export/media /mnt/media nfs defaults 0 0" >> /etc/fstab

# Or for CIFS/SMB
echo "//nas.local/media /mnt/media cifs credentials=/root/.smbcreds 0 0" >> /etc/fstab

# Mount
mount -a

# Verify
df -h | grep media
```

## 🎬 Media Organization

### Recommended Directory Structure

```
/mnt/media/
├── Movies/
│   ├── Movie Name (Year)/
│   │   └── Movie Name (Year).mp4
│   └── Another Movie (Year)/
│       └── Another Movie (Year).mkv
├── TV Shows/
│   ├── Show Name/
│   │   ├── Season 01/
│   │   │   ├── Show Name - S01E01 - Episode.mkv
│   │   │   └── Show Name - S01E02 - Episode.mkv
│   │   └── Season 02/
│   │       └── ...
├── Music/
│   ├── Artist/
│   │   └── Album/
│   │       └── tracks...
└── Photos/
```

### Naming Conventions

Plex works best with:
- **Movies**: `Movie Name (Year).ext`
- **TV Shows**: `Show Name - S##E## - Episode Name.ext`
- **Music**: Proper ID3 tags

## ⚙️ Optimization

### Hardware Transcoding

For Intel CPUs with Quick Sync:

```bash
# Check for hardware support
ls -l /dev/dri

# Install Intel media driver
apt install intel-media-va-driver-non-free

# Configure in Plex:
# Settings > Transcoder > Use hardware acceleration when available
```

### Performance Tuning

```bash
# Increase file watchers (for large libraries)
echo "fs.inotify.max_user_watches=524288" >> /etc/sysctl.conf
sysctl -p

# Optimize disk I/O
echo "vm.swappiness=10" >> /etc/sysctl.conf
sysctl -p
```

## 🔄 Maintenance

### Update Plex

```bash
# SSH to server
ssh root@<plex-ip>

# Update system and Plex
apt update && apt upgrade -y

# Or force Plex update
wget https://downloads.plex.tv/plex-keys/PlexSign.key
apt-key add PlexSign.key
apt update && apt install --only-upgrade plexmediaserver
```

### Backup Plex Configuration

```bash
# Stop Plex
systemctl stop plexmediaserver

# Backup Plex data
tar -czf plex-backup-$(date +%Y%m%d).tar.gz \
  /var/lib/plexmediaserver/Library/Application\ Support/Plex\ Media\ Server/

# Restart Plex
systemctl start plexmediaserver
```

### Restore from Backup

```bash
# Stop Plex
systemctl stop plexmediaserver

# Restore backup
tar -xzf plex-backup-YYYYMMDD.tar.gz -C /

# Fix permissions
chown -R plex:plex /var/lib/plexmediaserver

# Start Plex
systemctl start plexmediaserver
```

## 🐛 Troubleshooting

### Plex Not Accessible

```bash
# Check service status
systemctl status plexmediaserver

# Check logs
tail -f /var/lib/plexmediaserver/Library/Application\ Support/Plex\ Media\ Server/Logs/Plex\ Media\ Server.log

# Check network
netstat -tlnp | grep 32400

# Test local access
curl http://localhost:32400/web
```

### Media Not Scanning

```bash
# Check permissions
ls -la /mnt/media

# Fix permissions
chown -R plex:plex /mnt/media

# Force library scan
# In Plex Web: Library > ... > Scan Library Files
```

### Transcoding Issues

```bash
# Check transcoding directory
df -h /var/lib/plexmediaserver/Library/Application\ Support/Plex\ Media\ Server/Cache/Transcode

# Clear transcoding cache
rm -rf /var/lib/plexmediaserver/Library/Application\ Support/Plex\ Media\ Server/Cache/Transcode/*

# Check hardware acceleration
vainfo  # For Intel Quick Sync
```

### High CPU Usage

```bash
# Check what's transcoding
# Plex Web: Settings > Status > Now Playing

# Optimize transcoder settings
# Settings > Transcoder > Transcoder quality: Automatic
# Settings > Transcoder > Transcoder temporary directory: Fast disk

# Limit concurrent transcoding streams
# Settings > Transcoder > Maximum simultaneous video transcode: 2-3
```

## 🔐 Security

### Best Practices

- Use strong Plex account password
- Enable two-factor authentication on Plex account
- Restrict network access with firewall rules
- Keep Plex and OS updated
- Use HTTPS for remote access
- Regular backups

### Firewall Configuration

```bash
# Allow Plex locally
ufw allow from 192.168.0.0/16 to any port 32400

# Block external access (use Plex.tv for remote)
ufw deny 32400
```

## 📊 Monitoring

### Check Server Status

```bash
# Server info
curl http://localhost:32400/status/sessions | jq

# Plex status
systemctl status plexmediaserver

# Resource usage
htop
iotop -o
```

### Integration with Monitoring Stack

```bash
# Export Plex metrics (using Tautulli or similar)
# Configure Prometheus exporter
# Create Grafana dashboard
```

## 📚 Additional Resources

### Related Documentation
- [Cloud-init Configuration](../../scripts/deployment/cloud-init/README.md)
- [Terraform Modules](../../modules/README.md)

### External Links
- [Plex Support](https://support.plex.tv/)
- [Plex Forums](https://forums.plex.tv/)
- [Plex Docker](https://github.com/plexinc/pms-docker)

## 🤝 Contributing

Improvements welcome:
- Better resource allocation
- Additional optimization tips
- Hardware transcoding guides
- Monitoring integration

---

**Maintained by**: HomeLab Team  
**Last Updated**: January 2026  
**Plex Version**: Latest stable
