# Network topology and traffic paths

This diagram combines workload placement with the two important cross-boundary paths: infrastructure delivery and public ingress. It intentionally omits physical switch ports, full addressing, and firewall rule details.

```mermaid
flowchart TB
    User(["Public user"])
    Admin(["Administrator"])

    subgraph SaaS["External control and edge services"]
        direction LR
        GitHub["GitHub"]
        HCP["HCP Terraform"]
        CF["Cloudflare edge"]
        R2[("Cloudflare R2")]
    end

    subgraph Home["Home network"]
        Edge["Router + firewall"]
        Switch["Managed switch"]
        PVE["Proxmox VE<br/>vmbr0 trunk"]

        Edge --> Switch --> PVE

        subgraph CI["CI management zone"]
            Runners["GitHub Actions<br/>controller + workers"]
        end

        subgraph ProdZone["Production service zone"]
            PlexPrd["Plex production"]
            NFSPrd[("NFS production")]
            PlexPrd -->|media mount| NFSPrd
        end

        subgraph ClientZone["Client zone"]
            Win11["Windows 11"]
        end

        subgraph LabZone["Lab zone"]
            OpenClaw["OpenClaw hosts"]
            Pwnbox["pwnbox"]
            CmdProd["cmd_and_ctrl<br/>production"]
            CmdDev["cmd_and_ctrl<br/>development"]
        end

        subgraph AppZone["Development + application zone"]
            Gateway["Internal gateway<br/>+ portal"]
            Frontends["Private frontends"]
            LastDash["LastDash"]
            PlexDev["Plex development"]
            NFSDev[("NFS development")]
            Gateway --> Frontends
            Gateway --> LastDash
            PlexDev -->|media mount| NFSDev
        end

        PVE --> CI
        PVE --> ProdZone
        PVE --> ClientZone
        PVE --> LabZone
        PVE --> AppZone
    end

    Admin -->|management path| Edge
    Admin -->|private HTTPS| Gateway
    User --> CF
    CF <-->|outbound tunnels| CmdProd
    CF <-->|Terraform-managed dev tunnel| CmdDev
    CmdProd -.->|encrypted backup| R2
    CmdDev -.->|encrypted backup| R2
    Gateway -.->|DNS-01| CF

    Runners <--> GitHub
    Runners <--> HCP
    Runners -->|management plane| PVE

    classDef person fill:#8250df,stroke:#6639ba,color:#fff;
    classDef edge fill:#57606a,stroke:#424a53,color:#fff;
    classDef network fill:#1a7f37,stroke:#116329,color:#fff;
    classDef prod fill:#0969da,stroke:#0550ae,color:#fff;
    classDef lab fill:#bf8700,stroke:#9a6700,color:#fff;
    classDef dev fill:#8250df,stroke:#6639ba,color:#fff;
    classDef storage fill:#bc4c00,stroke:#953800,color:#fff;

    class User,Admin person;
    class GitHub,HCP,CF,R2 edge;
    class Edge,Switch,PVE,Runners network;
    class PlexPrd,Win11 prod;
    class OpenClaw,Pwnbox,CmdProd,CmdDev lab;
    class Gateway,Frontends,LastDash,PlexDev dev;
    class NFSPrd,NFSDev storage;
```

## What the arrows mean

- Solid arrows inside the Proxmox boundary show attachment or a required service path.
- Tunnel arrows show public traffic terminating at Cloudflare and reaching the guests through outbound connectors.
- The internal gateway path is available only to trusted clients and VPN users; its Cloudflare traffic is outbound certificate automation, not public ingress.
- Dashed R2 arrows show application-owned backup traffic.
- Runner arrows show why the CI network is trusted: it reaches GitHub, state, and Proxmox management interfaces.

VLAN identifiers, internal addressing, switch ports, firewall policy, DHCP pools, and internal DNS are intentionally omitted from this public view. They remain authoritative in Terraform and on the network platform.
