# Ansible

Ansible is planned for configuration convergence after first boot, but it is not part of the current production path. This directory intentionally contains no inventory, playbooks, or roles yet.

Today, Terraform creates infrastructure and cloud-init performs initial guest setup. That works well for reconstruction but leaves a gap for repeatable in-place configuration updates. Ansible may eventually fill that gap for tasks such as:

- operating-system patching
- baseline SSH and account policy
- package and service configuration
- configuration drift checks
- rolling application prerequisites

Before adding Ansible automation, establish:

1. a dynamic or generated inventory that does not commit private addressing unnecessarily
2. SSH host-key verification and a secure credential source
3. environment and role boundaries that match the Terraform deployments
4. idempotence checks in CI
5. a canary path before production rollout

Do not duplicate infrastructure ownership in playbooks. Terraform should continue to own Proxmox resources, disks, and network attachment; Ansible should own guest configuration after the machine exists.

See the [architecture overview](../docs/overview.md) for the current provisioning model.
