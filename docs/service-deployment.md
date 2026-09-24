# Service deployment guide

Services in this lab are delivered in one of two ways: baked into first boot with cloud-init, or updated later through a service-specific workflow or maintenance script. Choosing the right path matters because cloud-init is not rerun as a general deployment engine.

## Choose a deployment shape

| Need | Preferred shape |
| --- | --- |
| New long-lived Linux host | Reusable `pm-cloudinit-vm` module plus a cloud-init template |
| Guest with unusual hardware or lifecycle rules | Raw Proxmox resource with the reason documented inline |
| Small containerized application | Docker Compose rendered into a dedicated VM |
| Lightweight storage service | LXC container when its privilege and mount requirements are understood |
| Application update on an existing host | Application pipeline or focused maintenance script |
| First-boot package and account setup | Cloud-init |

## Add a service

### 1. Pick the state boundary

Add the service to an existing deployment only when it shares that stack's lifecycle and ownership. Otherwise create a new directory under `terraform/deployments/` with its own backend, providers, variables, version constraints, and environment files.

### 2. Define the guest

For a standard Ubuntu VM, use the current compute module:

```hcl
module "service_host" {
  source = "git::https://github.com/krakenhavoc/HomeLab.git//terraform/modules/compute/pm-cloudinit-vm?ref=<release>"

  vm_name                        = var.service_host.name_prefix
  vm_node_name                   = var.pve.host
  vm_description                 = var.service_host.description
  vm_tags                        = var.service_host.tags
  vm_bios                        = var.service_host.bios
  clone_vm_id                    = data.proxmox_virtual_environment_vms.noble_template.vms[0].vm_id
  vm_cpu_cores                   = var.service_host.cpu_cores
  vm_memory_mb                   = var.service_host.memory_mb
  vm_disk_datastore_id           = var.vm_disk_datastore_id
  vm_disk_interface              = var.service_host.disk_interface
  vm_disk_size                   = var.service_host.os_disk_size
  vm_cloudinit_datastore_id      = var.vm_cloudinit_datastore_id
  vm_cloudinit_user_data_file_id = proxmox_virtual_environment_file.service_cloudinit.id
  vm_network_bridge              = var.service_host.network_bridge
  vm_vlan_id                     = var.service_host.vlan_id
}
```

Pin the module to a release. Do not point production deployments at a moving branch.

### 3. Write first-boot configuration

Keep cloud-init focused on reconstructing the host:

- create the service account
- install the runtime and required packages
- write configuration from non-secret inputs
- enable the service
- leave a clear completion message and logs

Map required secret variables to Bitwarden item identifiers in the environment's `secrets.env` file. CI resolves the values at runtime. Avoid commands that echo those values or embed them in publicly readable files.

### 4. Place it on the network

Choose the VLAN based on trust and dependency boundaries, not convenience. Document any new inter-VLAN flow. If a stable address is required, follow the checks in the [network guide](network-setup.md).

### 5. Add delivery

For a normal tiered application, use the standard `env/<tier>/terraform.tfvars` layout so `deploy.yaml` can discover it. Confirm that:

- the application is represented in the Terraform Cloud workspace map
- secret identifiers live beside the tier without exposing secret values
- pull requests produce the expected plan summary and encrypted plan artifact
- a merge applies the reviewed plan rather than creating a new one
- the selected GitHub environment has the narrowest permissions and access possible

Use a dedicated workflow only for platform stacks whose lifecycle does not fit the tiered deployment matrix. The runner workflow is deliberately manual because it manages the machines that execute the normal path.

### 6. Prove the change

Before merge:

```bash
terraform fmt -recursive terraform/
pre-commit run --all-files
```

Review the remote plan for replacement and secret-handling surprises. After apply, verify Proxmox state, cloud-init completion, network placement, and application health.

## Updating an existing service

Changing Terraform should represent an infrastructure change: sizing, disks, network attachment, provider-managed resources, or reconstructible first-boot configuration.

Use an application delivery path for ordinary releases. Examples in this repository include the OpenClaw maintenance scripts under `scripts/deployments/openclaw/` and the external deployment pipeline used by `cmd_and_ctrl`.

If a guest ignores `initialization` changes, that is an intentional safety choice. Decide whether the change can be delivered in place or whether the guest needs a scheduled replacement; do not remove lifecycle protection just to make the plan non-empty.

## Stateful services

Before adding state, decide where each class of data lives:

| Data | Recommended owner |
| --- | --- |
| Terraform resource state | HCP Terraform |
| Rebuildable OS and packages | Template plus cloud-init |
| Application release | Application repository or container registry |
| Service data | Dedicated disk, network storage, or managed object storage |
| Secrets | GitHub environment or service-specific secret store |
| Backups | A different failure domain from the guest |

A VM disk is persistence, not a backup. A cloud-init template is rebuild automation, not data recovery.

## Definition of done

- [ ] The deployment boundary and owner are clear.
- [ ] The plan contains only expected changes.
- [ ] Secrets never enter tracked files or logs.
- [ ] Network access is no broader than the service needs.
- [ ] First boot and subsequent application updates have separate paths.
- [ ] Health checks and rollback are documented.
- [ ] Stateful data has a tested recovery path.
- [ ] The root README or architecture docs reflect a meaningful new capability.
