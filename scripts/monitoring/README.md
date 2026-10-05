# Monitoring scripts

Monitoring automation is planned but not implemented in this directory.

The one monitoring stack that exists is application-specific: the `cmd_and_ctrl` monitoring VM, defined in `terraform/deployments/cmd-and-ctrl-monitoring` with its runtime configuration in [`cmd-and-ctrl-monitoring/`](../../cmd-and-ctrl-monitoring/README.md). This directory remains the place for lab-wide checks.

The first useful checks should cover the failure modes that are otherwise easy to miss:

- Proxmox host and storage capacity
- guest reachability and failed systemd units
- self-hosted runner availability
- NFS export and mount health
- backup success and age
- TLS and public endpoint availability
- Terraform workflow failures

New checks should emit machine-readable status, avoid logging credentials, define their timeout, and link to a runbook action. Alerting without an owner or recovery step only moves ambiguity to a notification channel.

Operational troubleshooting remains in the [runbook](../../docs/runbook.md) until these checks are codified.
