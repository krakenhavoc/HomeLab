# Documentation

This directory explains how the lab is designed, deployed, and recovered. The root [README](../README.md) is the portfolio overview; the pages here are the operator's reference.

## Start here

| Document | Use it when you need to... |
| --- | --- |
| [Architecture overview](overview.md) | Understand the system boundaries and why the repository is organized this way |
| [Operations runbook](runbook.md) | Plan, deploy, replace, or troubleshoot infrastructure |
| [Network design](network-setup.md) | Understand VLAN placement and network dependencies |
| [Gateway and internal portal](gateway.md) | Understand the private reverse-proxy and portal design |
| [Service deployment](service-deployment.md) | Add a workload or change an existing service |
| [Security model](security.md) | Work with credentials, access controls, or incident response |
| [Backup strategy](backup-strategy.md) | Recover a service or evaluate what is and is not protected |
| [Diagram gallery](../diagrams/README.md) | Explore the platform, deployment, network, delivery, and recovery flows visually |

## Source-of-truth boundaries

The repository documents several kinds of information, but not all of them belong in Git:

| Source | Owns |
| --- | --- |
| Terraform | Proxmox resources, VM sizing, VLAN attachment, and cloud-init inputs |
| HCP Terraform | State and workspace separation |
| Bitwarden Secrets Manager and GitHub environments | Deployment credentials and sensitive variables |
| Router/firewall configuration | DHCP scopes, inter-VLAN policy, and upstream routing |
| Proxmox | Runtime status, snapshots, backup jobs, and console access |
| These docs | Intent, safe operating procedures, and recovery context |

When documentation and executable configuration disagree, verify the live system and then update both. Do not copy credentials, tokens, private keys, or backup contents into a documentation change.

## Documentation conventions

- Commands are run from the repository root unless a page says otherwise.
- Examples use placeholders such as `<environment>` and `<resource-address>`.
- `prd` means production; `dev` means a development environment.
- A capability described as **planned** has documentation or a reserved directory but is not yet implemented here.
- Destructive commands include an explicit warning and a verification step.
