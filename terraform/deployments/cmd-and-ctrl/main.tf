# cmd_and_ctrl game server: cmd.labxp.io (prd) and cmd-dev.labxp.io (dev).
# One instance per workspace. Moved out of lab/; see imports.tf.
#
# Hostnames stay one label under the zone: Universal SSL covers *.labxp.io
# only, so a nested name fails the TLS handshake at the edge.
#
# dev and prd differ only in hostname, fqdn, tokens and CMDCTRL_ENV, so the
# app's CD deploys both the same way.

locals {
  tunnel_token = (var.cmd_and_ctrl.manage_tunnel
    ? data.cloudflare_zero_trust_tunnel_cloudflared_token.this[0].token
  : var.cmd_and_ctrl_tunnel_token)

  github_token = var.cmd_and_ctrl.bug_reports ? var.cmd_and_ctrl_github_token : ""
}

# --- Cloudflare: managed tunnel, ingress and DNS (dev) -----------------------
# config_src = "cloudflare" is load-bearing: without it the connector expects a
# local config file and the tunnel is healthy but returns 502.

resource "cloudflare_zero_trust_tunnel_cloudflared" "this" {
  count = var.cmd_and_ctrl.manage_tunnel ? 1 : 0

  account_id = var.cloudflare_account_id
  name       = var.cmd_and_ctrl.name_prefix
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "this" {
  count = var.cmd_and_ctrl.manage_tunnel ? 1 : 0

  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this[0].id

  config = {
    ingress = [
      {
        hostname = var.cmd_and_ctrl.fqdn
        # Caddy on the VM, plain HTTP; Cloudflare terminates TLS.
        service = "http://localhost:80"
      },
      # Required catch-all.
      {
        service = "http_status:404"
      },
    ]
  }
}

resource "cloudflare_dns_record" "this" {
  count = var.cmd_and_ctrl.manage_tunnel ? 1 : 0

  zone_id = var.cloudflare_zone_id
  name    = var.cmd_and_ctrl.fqdn
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.this[0].id}.cfargotunnel.com"
  proxied = true
  # Proxied records must use TTL 1 (automatic).
  ttl = 1
}

# --- Proxmox -----------------------------------------------------------------

resource "proxmox_virtual_environment_file" "cloudinit" {
  provider     = pve
  content_type = "snippets"
  datastore_id = "snippets"
  node_name    = var.pve.host

  source_raw {
    data = templatefile("${path.module}/templates/setup-cmd_and_ctrl.yaml.tftpl", {
      hostname       = var.cmd_and_ctrl.name_prefix
      admin_username = var.cmd_and_ctrl.admin_username
      fqdn           = var.cmd_and_ctrl.fqdn
      cmdctrl_env    = var.cmd_and_ctrl.cmdctrl_env
      admin_token    = var.cmd_and_ctrl_admin_token
      tunnel_token   = local.tunnel_token
      github_token   = local.github_token
    })
    file_name = "setup-${var.cmd_and_ctrl.name_prefix}.yaml"
  }
}

# Raw resource, not pm-cloudinit-vm: it needs a data disk and the lifecycle
# block below, which a module call can't take.
resource "proxmox_virtual_environment_vm" "this" {
  provider = pve

  name        = var.cmd_and_ctrl.name_prefix
  node_name   = var.pve.host
  description = var.cmd_and_ctrl.description
  tags        = sort(concat(["terraform"], var.cmd_and_ctrl.tags))
  bios        = var.cmd_and_ctrl.bios

  clone {
    vm_id = data.proxmox_virtual_environment_vms.noble_template.vms[0].vm_id
    full  = true
  }

  agent {
    enabled = true
    trim    = true
  }

  cpu {
    cores = var.cmd_and_ctrl.cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = var.cmd_and_ctrl.memory_mb
  }

  # OS disk, cloned from the template.
  disk {
    datastore_id = var.vm_disk_datastore_id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = var.cmd_and_ctrl.os_disk_size
  }

  # CMDCTRL_DATA_DIR (Scryfall dump + image cache), mounted at /var/lib/cmd_and_ctrl.
  disk {
    datastore_id = var.vm_disk_datastore_id
    interface    = "virtio1"
    iothread     = true
    discard      = "on"
    size         = var.cmd_and_ctrl.data_disk_size
    file_format  = "raw"
  }

  initialization {
    datastore_id = var.vm_cloudinit_datastore_id
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
    user_data_file_id = proxmox_virtual_environment_file.cloudinit.id
  }

  network_device {
    bridge  = var.cmd_and_ctrl.network_bridge
    vlan_id = var.cmd_and_ctrl.vlan_id
  }

  serial_device {}

  vga {
    type = "std"
  }

  operating_system {
    type = "l26"
  }

  # A snippet change replaces the file, whose id is then unknown at plan time,
  # which replaces the VM. That destroyed prd and its data disk on 2026-09-10.
  # Template edits reach a running host through the app's CD, or a deliberate
  # rebuild (drop prevent_destroy first). clone isn't read back on import.
  lifecycle {
    ignore_changes  = [clone, initialization]
    prevent_destroy = true
  }
}

# --- R2 off-node backups -----------------------------------------------------
# Only the bucket lives here; cmd_and_ctrl#1031 owns the restic job, the
# bucket-scoped credentials and the restore runbook (HomeLab#58).

resource "cloudflare_r2_bucket" "backup" {
  account_id = var.cloudflare_account_id
  name       = var.cmd_and_ctrl.backup_bucket

  # Free tier only covers Standard.
  storage_class = "Standard"

  lifecycle {
    prevent_destroy = true
  }
}

# No expiry rules: retention is restic's forget --prune, and age-based expiry
# would delete packs a snapshot still needs. This rule only aborts abandoned
# multipart uploads.
resource "cloudflare_r2_bucket_lifecycle" "backup" {
  account_id  = var.cloudflare_account_id
  bucket_name = cloudflare_r2_bucket.backup.name

  rules = [
    {
      id      = "abort-incomplete-multipart-uploads"
      enabled = true
      conditions = {
        prefix = ""
      }
      abort_multipart_uploads_transition = {
        condition = {
          type    = "Age"
          max_age = 7 * 24 * 60 * 60
        }
      }
    }
  ]
}
