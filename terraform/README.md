# Terraform

Terraform is the production control plane for compute in this lab. Each deployment is a separate root module, HCP Terraform stores remote state, and GitHub Actions provides the normal plan-and-apply path.

## Layout

```text
terraform/
├── deployments/
│   ├── cmd-and-ctrl/  Application hosts, ingress, and backup buckets
│   ├── frontends/     Internal gateway and private frontend host
│   ├── gh-runner/     Self-hosted Actions controller and workers
│   ├── lab/           Lab and interactive VMs
│   ├── lastdash/      Stateful LastDash host
│   ├── nfs/           NFS LXC containers
│   ├── plex/          Plex development and production VMs
│   ├── shared/        Templates, drivers, and installation media
│   └── tfc/           HCP Terraform projects and workspaces
├── modules/
│   ├── compute/       Reusable Proxmox VM modules
│   └── network/       Reserved for future network modules
└── install.sh         Terraform installer for Debian/Ubuntu
```

## Deployment matrix

| Deployment | Environments / workspaces | Main resources |
| --- | --- | --- |
| `cmd-and-ctrl` | `cmd-and-ctrl-dev`, `cmd-and-ctrl-prd` | Application VMs, Cloudflare Tunnels/DNS, and R2 buckets |
| `frontends` | `frontends-prd` | Gateway VM, cloud-init, and Docker Compose bootstrap |
| `gh-runner` | `GH-Controller`, `GH-Worker` | Runner VMs and cloud-init snippets |
| `lab` | `lab` | OpenClaw, pwnbox, and Windows VMs |
| `lastdash` | `lastdash-prd` | Stateful application VM and first-boot bootstrap |
| `nfs` | `nfs-dev`, `nfs-prd` | Privileged LXC containers and NFS provisioning |
| `plex` | `plex-dev`, `plex-prd` | Ubuntu VMs and Plex Compose configuration |
| `shared` | `shared` | Ubuntu LXC template, VirtIO ISO, optional Windows ISO |
| `tfc` | `tfc` | HCP Terraform projects, workspaces, tags, and settings |

The shared deployment provides artifacts that other deployments expect, but the stacks do not share a Terraform state file.

## Requirements

- Terraform `~> 1.14.3` for root deployments
- access to the configured HCP Terraform organization
- Proxmox API credentials
- SSH agent access for deployments that upload snippets or perform provider-side disk work
- Bitwarden Secrets Manager access for deployments that resolve secret values by identifier
- Cloudflare credentials for deployments that manage tunnels, DNS, certificates, or R2

Install Terraform on Debian or Ubuntu with:

```bash
sudo ./terraform/install.sh 1.14.3
```

Review the script before running it; it adds HashiCorp's apt repository and installs a system package.

## Work locally

Initialize only the deployment you are changing:

```bash
cd terraform/deployments/plex
export TF_WORKSPACE=plex-dev

terraform init
terraform fmt -check -recursive
terraform validate
terraform plan -var-file=env/dev/terraform.tfvars
```

Use environment variables for credentials. A typical provider token uses the name expected by its provider or a `TF_VAR_...` variable already declared by the deployment.

Never commit local state, saved plans, crash logs, or credential files. The repository `.gitignore` files cover common cases, but they are not a security boundary.

## State model

Backends use HCP Terraform. Some deployments select a fixed workspace; others select from workspaces grouped by tags. CI sets `TF_WORKSPACE` from the workflow environment.

State rules:

- one deployment owns a resource
- do not copy a resource between state files by editing configuration alone
- back up state before a manual move or import
- quote addresses containing `for_each` keys
- treat state and plan files as sensitive

Useful read-only commands:

```bash
terraform workspace show
terraform state list
terraform state show '<resource-address>'
terraform show
```

## Delivery model

The central `deploy.yaml` workflow detects changed tiered deployments and calls the reusable Terraform CI and CD workflows:

1. initialize and validate the selected deployment
2. create a saved plan
3. resolve the environment's Bitwarden secret identifiers
4. post a change summary on pull requests
5. encrypt and upload the saved plan as a short-lived artifact
6. after merge, retrieve and apply the successful pull-request plan without replanning `main`

The shared CD workflow independently checks that the event targets `main`. The `shared`, `tfc`, and runner stacks keep dedicated workflows because they are platform deployments rather than ordinary tiered applications.

The runner deployment is different because it manages the infrastructure that runs the other workflows. It is manually dispatched, defaults to `dry_run: true`, rejects deletes, and checks for duplicate runner registrations before applying.

## Cloud-init lifecycle

The BPG Proxmox provider stores a cloud-init snippet as a file resource and refers to its ID from the VM's `initialization` block. Replacing a snippet can make that ID unknown during planning, which can cascade into a VM replacement.

For disposable guests that may be acceptable. For long-lived services and registered runners it is not, so selected raw VM resources ignore initialization changes. The tradeoff is important: later edits to the cloud-init template no longer reach those existing guests. Use an application update path or a deliberate rebuild.

Always inspect changes to:

- `initialization`
- `user_data_file_id`
- clone source and disk blocks
- a resource's `for_each` key or address
- `moved` blocks
- lifecycle rules

## Shared compute module

`modules/compute/pm-cloudinit-vm` is the current BPG Proxmox module. It creates a full-clone Linux VM with:

- QEMU agent support
- configurable CPU, memory, disk, BIOS, tags, bridge, and VLAN
- a caller-provided cloud-init file ID
- DHCP by default
- optional static IPv4, gateway, DNS, search domain, and pinned MAC address

Deployments consume it by versioned Git reference. See the [compute module guide](modules/compute/README.md) for usage and release notes.

`modules/compute/pve-cloudinit-vm` is the earlier Telmate-provider implementation. It remains for historical compatibility but is not the preferred module for new deployments.

## Validate modules

```bash
cd terraform/modules/compute/pm-cloudinit-vm
terraform init -backend=false
terraform validate
terraform test
```

The repository discovers modules with a `tests/` directory and runs them in GitHub Actions when module files change.

## Intentional replacement

Use the manual replacement workflow only after confirming the exact state address, backup, downtime, and recovery path. It prints a plan and then performs an auto-approved apply, so a correct dispatch input is critical.

See the [operations runbook](../docs/runbook.md#intentional-replacement) for the procedure and current runner-stack limitation.

## Adding a deployment

A new root module should include:

- `backend.tf` with an intentional workspace boundary
- `versions.tf` with Terraform and provider constraints
- `providers.tf`
- typed, described variables with validation where useful
- non-secret environment values under `env/`
- an `env/<tier>/terraform.tfvars` directory that the deployment matrix can discover
- secret identifiers in `env/<tier>/secrets.env` when the stack needs them
- a service verification and recovery note

Start with the [service deployment guide](../docs/service-deployment.md) rather than copying an old stack wholesale.
