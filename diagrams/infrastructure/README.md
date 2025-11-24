# Infrastructure Diagrams

This directory contains infrastructure architecture diagrams for the homelab.

## Diagrams Available

### System Architecture
- **infrastructure-overview.drawio**: High-level infrastructure overview
- **infrastructure-overview.png**: Visual representation of all systems

### Virtualization Architecture
- **proxmox-cluster.drawio**: Proxmox cluster architecture
- **docker-swarm.drawio**: Docker container architecture
- **kubernetes-cluster.drawio**: K3s cluster topology

### Storage Architecture
- **storage-layout.drawio**: Storage pools and volumes
- **backup-architecture.drawio**: Backup infrastructure flow

### Service Architecture
- **service-map.drawio**: Service dependencies and relationships
- **monitoring-stack.drawio**: Monitoring and observability architecture

## Infrastructure Overview

```
┌─────────────────────────────────────────────────────────┐
│                    Proxmox Cluster                      │
│  ┌──────────┐  ┌──────────┐  ┌──────────┐             │
│  │  Node 1  │  │  Node 2  │  │  Node 3  │             │
│  │ (Master) │  │          │  │          │             │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘             │
│       │             │             │                     │
│       └─────────────┴─────────────┘                     │
│                     │                                   │
│              ┌──────┴───────┐                           │
│              │   ZFS Pool   │                           │
│              │   (Shared)   │                           │
│              └──────────────┘                           │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│              Virtual Machines & Containers              │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐       │
│  │   Docker   │  │     K8s    │  │    Apps    │       │
│  │   Host     │  │   Cluster  │  │    VMs     │       │
│  └────────────┘  └────────────┘  └────────────┘       │
└─────────────────────────────────────────────────────────┘

┌─────────────────────────────────────────────────────────┐
│                   Storage Layer                         │
│  ┌────────────┐  ┌────────────┐  ┌────────────┐       │
│  │  TrueNAS   │  │   Backup   │  │   Cloud    │       │
│  │    NAS     │  │   Server   │  │  Storage   │       │
│  └────────────┘  └────────────┘  └────────────┘       │
└─────────────────────────────────────────────────────────┘
```

## Component Details

### Compute Layer
- **Proxmox VE**: Hypervisor for VMs
- **Docker**: Container runtime
- **Kubernetes (K3s)**: Container orchestration

### Storage Layer
- **Local Storage**: NVMe SSD for OS and critical VMs
- **ZFS Pools**: Shared storage for VMs
- **TrueNAS**: Network-attached storage
- **PBS**: Proxmox Backup Server

### Network Layer
- **Management Network**: 1 Gbps
- **Storage Network**: 10 Gbps (iSCSI/NFS)
- **VM Network**: 1 Gbps
- **External Network**: 1 Gbps WAN

## Diagram Formats

### Draw.io Diagrams
- Editable source files
- Can be opened at https://app.diagrams.net/
- Version controlled for change tracking

### PNG Exports
- High-resolution images for documentation
- Easy viewing in GitHub
- Embedded in markdown docs

### PlantUML Source
- Text-based diagram definitions
- Version control friendly
- Automated rendering possible

## Creating New Diagrams

### Standard Colors
- **Network Devices**: Blue (#2196F3)
- **Servers**: Green (#4CAF50)
- **Storage**: Orange (#FF9800)
- **Security**: Red (#F44336)
- **Virtual**: Purple (#9C27B0)
- **Monitoring**: Yellow (#FFC107)

### Icon Sources
- [Font Awesome](https://fontawesome.com/)
- [Material Design Icons](https://materialdesignicons.com/)
- [Cisco Icons](https://www.cisco.com/c/en/us/about/brand-center/network-topology-icons.html)

## Documentation Integration

Reference diagrams in documentation using:

```markdown
![Infrastructure Overview](../diagrams/infrastructure/infrastructure-overview.png)
```

## Maintenance

- Update diagrams when infrastructure changes
- Review diagrams quarterly
- Ensure consistency across all diagrams
- Keep source files and exports in sync

## Tools and Resources

- **draw.io**: Free diagramming tool
- **PlantUML**: Text-based diagrams
- **Mermaid**: Markdown-native diagrams
- **Visio**: Professional diagramming (optional)

## Future Enhancements

- Automated diagram generation from infrastructure
- Interactive diagrams with links
- Real-time status indicators
- Integration with monitoring systems
