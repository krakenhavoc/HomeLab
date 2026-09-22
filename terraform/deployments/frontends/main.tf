resource "proxmox_virtual_environment_file" "pfe_host_cloudinit" {
  provider     = pve
  content_type = "snippets"
  datastore_id = "snippets"
  node_name    = var.pve.host

  source_raw {
    data = templatefile("${path.module}/templates/setup-pfe.yaml.tftpl", {
      hostname       = "${var.pfe_host.name_prefix}-${var.pfe_host.env}",
      admin_username = "pfe"

      # Cosmetic -- it only reaches the final_message banner -- but the
      # address is the one fact an operator staring at the Proxmox console
      # most wants and cannot look up from there.
      ipv4_address = var.pfe_host.ipv4_address

      # The only secret this host holds. Everything else the gateway needs
      # lives in gateway/ in this repository, which is public.
      cloudflare_api_token = var.cloudflare_api_token
    })
    file_name = "setup-pfe-${var.pfe_host.env}.yaml"
  }
}

# pfe is the lab gateway: Caddy terminates TLS for every internal name and
# proxies to the service behind it, with a Homepage portal at the labxp.io apex.
# See docs/gateway.md for the design and gateway/ for the runtime config.
module "pfe_host" {
  source = "git::https://github.com/krakenhavoc/HomeLab.git//terraform/modules/compute/pm-cloudinit-vm?ref=v0.3.0"

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

  # --- Static addressing ------------------------------------------------------
  # Every internal DNS name resolves to this address, on both Pi-holes, so it
  # cannot be a DHCP lease. openclaw-2 came back on a different address after
  # a rebuild and everything naming the old one quietly pointed at nothing;
  # the same rebuild here would break every name in the lab at once.
  #
  # dns_servers is not optional alongside a static address. Taking the host
  # off DHCP takes its resolvers with it, and this host's first boot clones a
  # repository and pulls four container images -- an empty resolv.conf does
  # not fail fast, it hangs.
  vm_ipv4_address = var.pfe_host.ipv4_address
  vm_ipv4_gateway = var.pfe_host.ipv4_gateway
  vm_dns_servers  = var.pfe_host.dns_servers
  vm_dns_domain   = var.pfe_host.dns_domain
}
