# Network modules

No Terraform network module is implemented here yet.

Guest network attachment currently lives with each Proxmox resource: the deployment chooses `vmbr0`, an optional VLAN ID, and either DHCP or cloud-init static addressing. Routing, DHCP scopes, DNS, firewall policy, and switch configuration are managed outside this repository.

This directory is reserved for a future module only if the network control plane becomes manageable through a stable provider and importing the existing configuration can be done without disruption.

Before adding one, document:

- which system remains authoritative for VLANs and firewall rules
- how existing objects will be imported
- the state and failure boundary
- the plan and rollback for the first managed change
- how credentials will be scoped

See the [network design](../../../docs/network-setup.md) for the current model.
