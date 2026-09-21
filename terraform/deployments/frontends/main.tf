resource "proxmox_virtual_environment_file" "pfe_host_cloudinit" {
  provider     = pve
  content_type = "snippets"
  datastore_id = "snippets"
  node_name    = var.pve.host

  source_raw {
    data = templatefile("${path.module}/templates/setup-pfe.yaml.tftpl", {
      hostname       = "${var.pfe_host.name_prefix}-${var.pfe_host.env}",
      admin_username = "pfe"
      docker_compose = indent(6, local.docker_compose)
      redlib_env     = indent(6, local.redlib_env)
    })
    file_name = "setup-pfe-${var.pfe_host.env}.yaml"
  }
}

module "pfe_host" {
  source = "git::https://github.com/krakenhavoc/HomeLab.git//terraform/modules/compute/pm-cloudinit-vm?ref=v0.2.0"

  vm_name                        = "${var.pfe_host.name_prefix}-${var.pfe_host.env}"
  vm_node_name                   = var.pve.host
  vm_description                 = var.pfe_host.description
  vm_tags                        = var.pfe_host.tags
  vm_bios                        = var.pfe_host.bios
  clone_vm_id                    = data.proxmox_virtual_environment_vms.noble_template.vms[0].vm_id
  vm_cpu_cores                   = var.pfe_host.cpu_cores
  vm_memory_mb                   = var.pfe_host.memory_mb
  vm_disk_datastore_id           = var.vm_disk_datastore_id
  vm_disk_interface              = var.pfe_host.disk_interface
  vm_disk_size                   = var.pfe_host.os_disk_size
  vm_cloudinit_datastore_id      = var.vm_cloudinit_datastore_id
  vm_cloudinit_user_data_file_id = proxmox_virtual_environment_file.pfe_host_cloudinit.id
  vm_network_bridge              = var.pfe_host.network_bridge
  vm_vlan_id                     = var.pfe_host.vlan_id

  # --- Static addressing: INERT UNTIL THE MODULE REF ABOVE IS v0.3.0 ---------
  # Terraform rejects an argument the pinned module version does not declare
  # REGARDLESS OF ITS VALUE -- passing vm_ipv4_address = null against v0.2.0
  # is still "An argument named vm_ipv4_address is not expected here", which
  # turns frontends CI red on every run. So these stay commented until the ref
  # is bumped, not merely set to null.
  #
  # To turn this on, in one PR:
  #   1. Tag the module v0.3.0 (static addressing is merged to main but
  #      unreleased -- every deployment still pins v0.2.0).
  #   2. Change the ref above from v0.2.0 to v0.3.0.
  #   3. Uncomment the four lines below.
  #   4. Uncomment the matching values in env/frontends-dev/terraform.tfvars.
  #
  # THIS REPLACES THE VM. pfe is on DHCP today, so applying a static address
  # rewrites the cloud-init drive, and cloud-init network config is
  # first-boot-only -- the provider rebuilds the guest to make it take. Do it
  # NOW rather than later: today this host runs only stateless RedLib and a
  # rebuild costs nothing, but once Caddy holds the Let's Encrypt certificate
  # store (docs/gateway.md, phase 3) the same change burns rate-limit budget
  # (5 duplicate certs per week) and can leave the gateway with no usable
  # certificate.
  #
  # vm_ipv4_address = var.pfe_host.ipv4_address
  # vm_ipv4_gateway = var.pfe_host.ipv4_gateway
  # vm_dns_servers  = var.pfe_host.dns_servers
  # vm_dns_domain   = var.pfe_host.dns_domain
}
