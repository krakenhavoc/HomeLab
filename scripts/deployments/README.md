# Deployment utilities

These scripts support first-boot experiments, image preparation, and application maintenance. The active Terraform cloud-init templates live beside their deployments under `terraform/deployments/`; the older snippets here are retained as references.

## OpenClaw maintenance

Two hosts use different installation models, so they have separate update scripts:

| Script | Target | Action |
| --- | --- | --- |
| `openclaw/update-openclaw.sh` | Source-built fork under `/opt/openclaw` | Pull, install, build, and restart the gateway |
| `openclaw/update-openclaw-2.sh` | Upstream package install | Run the upstream updater and diagnostic check |

Run the matching script on the target VM. Neither script creates a backup or rolls back automatically; inspect the installed version and gateway status after use.

## Ubuntu template rebuild

`cloud-init/templates/update-noble-template.sh` downloads the current Ubuntu Noble cloud image and recreates Proxmox template VM `9000` on the configured datastore.

> **Destructive operation:** the script stops and purges VM ID `9000` if it exists. Run it only on the intended Proxmox host after confirming that ID is the template and no clone operation is in progress.

The script assumes Proxmox CLI tools, root-equivalent privileges, `vmbr0`, and the datastore values defined inside the file. Review those constants before execution.

## Historical Kubernetes bootstrap

The `cloud-init/snippets/setup-k8s-*.yaml` files and `cloud-init/kubernetes/calico-patch.sh` record an earlier kubeadm/Kubernetes 1.29 experiment. They are not referenced by a current Terraform deployment and should not be treated as a supported cluster installer.

Known reasons to review them before reuse include pinned old versions, a manual worker join step, upstream manifest changes, and repository paths embedded in the templates.

## Windows media helper

`shared/get_win_url.py` uses Selenium and Chrome to retrieve Microsoft's temporary Windows 11 ISO URL. The maintained container packaging lives under [`docker/get-win-url/`](../../docker/get-win-url/); the GitHub workflow builds and publishes that image.

Temporary media URLs expire. Pass the result to the manually dispatched shared deployment rather than committing it to a variable file.
