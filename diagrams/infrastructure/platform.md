# Platform architecture

This view shows the systems involved in changing and running the lab. It separates the delivery control plane from the Proxmox runtime and from services that remain external to the repository.

```mermaid
flowchart TB
    Operator([Maintainer])

    subgraph Delivery["Delivery control plane"]
        direction LR
        Repo["GitHub repository"]
        Actions["GitHub Actions"]
        Runner["Self-hosted runner"]
        State[("HCP Terraform state")]

        Repo --> Actions
        Actions --> Runner
        Runner <--> State
    end

    subgraph Network["Network control plane — managed outside this repository"]
        direction LR
        Edge["Router + firewall"]
        DNS["DNS + DHCP"]
        Switching["Managed switching"]

        Edge --> Switching
        DNS --> Switching
    end

    subgraph Runtime["HomeLab runtime"]
        direction TB
        PVE["Proxmox VE"]
        Images[("Templates + installation media")]

        subgraph Guests["Managed guests"]
            direction LR
            Lab["Lab VMs"]
            Apps["Application VMs"]
            Media["Media VMs"]
            Storage["NFS containers"]
            CIRunners["CI runner VMs"]
            Client["Windows client VM"]
        end

        Images --> PVE
        PVE --> Lab
        PVE --> Apps
        PVE --> Media
        PVE --> Storage
        PVE --> CIRunners
        PVE --> Client
    end

    subgraph External["External services"]
        direction LR
        Cloudflare["Cloudflare<br/>Tunnel, DNS, R2"]
        Registries["Package + container registries"]
        Upstream["GitHub + application upstreams"]
    end

    Operator --> Repo
    Operator -->|administration| PVE
    Runner -->|plan + apply| PVE
    Switching --> PVE
    Guests -->|updates + dependencies| Registries
    Lab <--> Cloudflare
    CIRunners <--> Upstream

    classDef person fill:#8250df,stroke:#6639ba,color:#fff;
    classDef delivery fill:#0969da,stroke:#0550ae,color:#fff;
    classDef network fill:#1a7f37,stroke:#116329,color:#fff;
    classDef compute fill:#218bff,stroke:#0969da,color:#fff;
    classDef storage fill:#bf8700,stroke:#9a6700,color:#fff;
    classDef external fill:#57606a,stroke:#424a53,color:#fff;

    class Operator person;
    class Repo,Actions,Runner,State delivery;
    class Edge,DNS,Switching network;
    class PVE,Lab,Apps,Media,CIRunners,Client compute;
    class Images,Storage storage;
    class Cloudflare,Registries,Upstream external;
```

## Ownership boundaries

| Boundary | Source of truth |
| --- | --- |
| Guest resources and attachment | Terraform in this repository |
| Resource identity and dependency state | HCP Terraform |
| First-boot guest configuration | Cloud-init templates |
| Pull-request checks and deployment | GitHub Actions |
| Routing, firewall, DNS, and DHCP | Network platform |
| Runtime status and consoles | Proxmox VE |
| Application data recovery | Workload-specific backup system |

The delivery systems are dependencies for making changes, but an outage in GitHub or HCP Terraform should not stop already-running guests. Proxmox and the network are runtime dependencies and therefore broader failure domains.
