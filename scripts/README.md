# Scripts

This directory holds focused utilities that support provisioning and maintenance. Scripts are not a second infrastructure control plane: each one should have a narrow purpose, explicit prerequisites, and a clear owner.

## Inventory

| Path | Status | Purpose |
| --- | --- | --- |
| [`deployments/openclaw/`](deployments/openclaw/) | Active | Update the two OpenClaw installation variants in place |
| [`deployments/cloud-init/templates/`](deployments/cloud-init/templates/) | Active, destructive | Rebuild the Ubuntu Noble Proxmox template |
| [`deployments/shared/get_win_url.py`](deployments/shared/get_win_url.py) | Reference | Obtain a temporary Windows 11 media URL with Selenium |
| [`deployments/cloud-init/kubernetes/`](deployments/cloud-init/kubernetes/) | Historical | Kubernetes/Calico bootstrap experiment, not a current deployment |
| [`deployments/cloud-init/snippets/`](deployments/cloud-init/snippets/) | Historical | Earlier static cloud-init snippets |
| [`backup/`](backup/) | Planned | Reserved for backup utilities |
| [`monitoring/`](monitoring/) | Planned | Reserved for monitoring utilities |

## Safety rules

- Read a script before running it.
- Run it from the documented host and account.
- Prefer `--help`, dry-run, or read-only modes when available.
- Do not place secrets directly in arguments or source files.
- Confirm the target resource before a template rebuild or replacement.
- Keep application updates separate from Terraform infrastructure changes.

Shell scripts are checked with ShellCheck and `shfmt`; Python utilities are checked with the repository's Python hooks.

## Adding a script

A useful script should include:

- a shebang and strict error handling
- a short usage comment
- dependency and privilege checks
- quoted variables and explicit paths
- useful failure messages
- cleanup for temporary files
- a note here if operators are expected to run it

If a task must run on every deployment, belongs in Terraform, or needs ongoing convergence, a standalone script is probably the wrong abstraction.
