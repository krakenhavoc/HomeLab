# Recovery decision flow

This chart is a first-response guide. It helps identify which source of truth to use before changing infrastructure during an outage.

```mermaid
flowchart TD
    Alert(["Service unavailable or degraded"])
    Alert --> Scope["Identify affected service,<br/>environment, and last good change"]
    Scope --> Network{"Guest reachable?"}

    Network -->|no| PVE{"Guest running in Proxmox?"}
    PVE -->|no| Host{"Proxmox host and<br/>storage healthy?"}
    Host -->|no| Platform["Restore hypervisor,<br/>network, and storage control"]
    Host -->|yes| Start["Inspect guest events,<br/>disk, and boot console"]
    PVE -->|yes| Path["Check VLAN, route,<br/>DHCP/DNS, and firewall"]

    Network -->|yes| Service{"Workload healthy?"}
    Service -->|yes| Dependency["Check upstream dependency,<br/>ingress, DNS, and client path"]
    Service -->|no| Data{"Persistent data intact?"}

    Data -->|yes| Repair["Repair or redeploy<br/>application in place"]
    Data -->|no or uncertain| Backup{"Verified backup available?"}
    Backup -->|yes| Rebuild["Rebuild infrastructure<br/>from Terraform + cloud-init"]
    Rebuild --> Restore["Restore application data"]
    Backup -->|no| Contain["Stop writes, preserve evidence,<br/>and choose documented fallback"]

    Platform --> Rebuild
    Start --> Data
    Path --> Network
    Dependency --> Verify["Verify from infrastructure<br/>through the user-facing service"]
    Repair --> Verify
    Restore --> Verify
    Contain --> Record["Record impact and<br/>open follow-up work"]
    Verify --> Record
    Record --> Improve["Add the missing guardrail,<br/>monitor, backup, or runbook step"]

    classDef start fill:#8250df,stroke:#6639ba,color:#fff;
    classDef decision fill:#bf8700,stroke:#9a6700,color:#fff;
    classDef inspect fill:#0969da,stroke:#0550ae,color:#fff;
    classDef recover fill:#1a7f37,stroke:#116329,color:#fff;
    classDef contain fill:#cf222e,stroke:#a40e26,color:#fff;

    class Alert start;
    class Network,PVE,Host,Service,Data,Backup decision;
    class Scope,Start,Path,Dependency inspect;
    class Platform,Repair,Rebuild,Restore,Verify,Record,Improve recover;
    class Contain contain;
```

## Recovery sources

| Problem | Start with |
| --- | --- |
| Resource missing or misconfigured | Terraform configuration, state history, and last reviewed plan |
| Guest cannot boot | Proxmox task history, console, disks, and template assumptions |
| Guest has no network | VLAN attachment, DHCP/static inputs, route, DNS, and firewall |
| Application broken but data intact | Application deployment path and service logs |
| Application data lost or corrupt | Verified off-node backup and workload restore procedure |
| Delivery system unavailable | Existing services continue running; restore runner and control-plane access before changing them |

The detailed commands and escalation notes remain in the [operations runbook](../../docs/runbook.md).
