resource "proxmox_virtual_environment_file" "lastdash_host_cloudinit" {
  provider     = pve
  content_type = "snippets"
  datastore_id = "snippets"
  node_name    = var.pve.host

  source_raw {
    data = templatefile("${path.module}/templates/setup-lastdash.yaml.tftpl", {
      hostname       = "${var.lastdash_host.name_prefix}-${var.lastdash_host.env}",
      admin_username = "lastdash"
      ipv4_address   = var.lastdash_host.ipv4_address

      token_encryption_secret = var.lastdash_token_encryption_secret
      nextauth_secret         = var.lastdash_nextauth_secret
      postgres_password       = var.lastdash_postgres_password
      ghcr_token              = var.lastdash_ghcr_token
    })
    file_name = "setup-lastdash-${var.lastdash_host.env}.yaml"
  }
}

# LastDash (https://lastdash.labxp.io): web, API, Postgres and Redis in one
# compose stack. The gateway (pfe) terminates TLS and proxies to this host on
# :3000 (web) and :3001 (API). Runtime config is lastdash/ in this repo,
# reconciled by lastdash-sync -- like gateway/ on pfe -- so app updates never
# touch Terraform. See lastdash/README.md.
#
# A raw resource rather than pm-cloudinit-vm, for the lifecycle block below:
# this host holds the LastDash database, and a module call cannot opt out of
# being replaced when its cloud-init snippet changes.
resource "proxmox_virtual_environment_vm" "lastdash" {
  provider = pve

  name        = "${var.lastdash_host.name_prefix}-${var.lastdash_host.env}"
  node_name   = var.pve.host
  description = var.lastdash_host.description
  tags        = sort(concat(["terraform"], var.lastdash_host.tags))
  bios        = var.lastdash_host.bios

  clone {
    vm_id = data.proxmox_virtual_environment_vms.noble_template.vms[0].vm_id
    full  = true
  }

  agent {
    enabled = true
    trim    = true
  }

  cpu {
    cores = var.lastdash_host.cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.lastdash_host.memory_mb
  }

  disk {
    datastore_id = var.vm_disk_datastore_id
    interface    = var.lastdash_host.disk_interface
    iothread     = true
    discard      = "on"
    size         = var.lastdash_host.os_disk_size
  }

  initialization {
    datastore_id = var.vm_cloudinit_datastore_id
    ip_config {
      ipv4 {
        address = var.lastdash_host.ipv4_address
        gateway = var.lastdash_host.ipv4_gateway
      }
    }
    dns {
      servers = var.lastdash_host.dns_servers
      domain  = var.lastdash_host.dns_domain
    }
    user_data_file_id = proxmox_virtual_environment_file.lastdash_host_cloudinit.id
  }

  network_device {
    bridge  = var.lastdash_host.network_bridge
    vlan_id = var.lastdash_host.vlan_id
  }

  serial_device {}

  vga {
    type = "std"
  }

  operating_system {
    type = "l26"
  }

  # Cloud-init is first-boot only. Without this, editing the template (or a
  # secret) replaces the snippet file, its id goes unknown at plan time, and
  # the VM is REPLACED -- taking the Postgres volume with it. That is how the
  # cmd_and_ctrl VM was lost on 2026-09-10.
  #
  # The cost: template and secret edits don't reach the running host. Change
  # /etc/lastdash/env on the host (see lastdash/README.md), or taint the VM
  # deliberately after backing up the database.
  lifecycle {
    ignore_changes = [initialization]
  }
}
