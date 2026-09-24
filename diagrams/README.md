# Diagrams

Architecture diagrams are kept in Markdown and Mermaid so they remain reviewable alongside the configuration and render directly on GitHub.

## Diagram gallery

| View | Question it answers |
| --- | --- |
| [Platform architecture](infrastructure/platform.md) | Which systems build, run, and support the lab? |
| [Deployment and service map](infrastructure/deployments.md) | What does each Terraform root manage, and which services depend on one another? |
| [Infrastructure delivery](infrastructure/delivery.md) | How does a change move from a branch to Proxmox? |
| [Network topology](network/topology.md) | Which trust zones and traffic paths matter? |
| [Recovery decision flow](infrastructure/recovery.md) | Where should incident diagnosis and recovery begin? |

Smaller diagrams also appear inline in the [architecture overview](../docs/overview.md), [network design](../docs/network-setup.md), and [backup strategy](../docs/backup-strategy.md).

## Public documentation boundary

These diagrams show architecture and engineering decisions without publishing a ready-made infrastructure inventory. They intentionally omit:

- internal IP addresses and subnets
- VLAN identifiers and switch-port assignments
- firewall rules and management entry points
- credentials, account identifiers, and secret names
- storage paths that are not needed to understand the design

The executable configuration and private network platform remain the sources of truth for those details.

## Viewing diagrams locally

VS Code 1.121 and newer renders Mermaid in its built-in Markdown preview. Open a Markdown file and use **Markdown: Open Preview to the Side** (`Ctrl+K V` on Windows and Linux, `Cmd+K V` on macOS) to see the rendered diagram.

If Mermaid blocks appear as source text or fail silently, remove the deprecated **Markdown Preview Mermaid Support** extension (`bierner.markdown-mermaid`) and reload VS Code. It conflicts with the built-in renderer in current VS Code releases:

```bash
code --uninstall-extension bierner.markdown-mermaid
```

The workspace marks that extension as unwanted so new contributors do not install the conflicting renderer by accident.

When adding a diagram, keep it focused on one question, use names found in the configuration, and update it in the same change as the architecture it describes.
