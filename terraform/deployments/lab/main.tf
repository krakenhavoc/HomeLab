resource "proxmox_virtual_environment_file" "openclaw_cloudinit" {
  provider     = pve
  content_type = "snippets"
  datastore_id = "snippets"
  node_name    = var.pve.host

  source_raw {
    data = templatefile("${path.module}/templates/setup-openclaw.yaml.tftpl", {
      openclaw_hostname = var.openclaw.name_prefix
      admin_username    = var.openclaw.admin_username
    })
    file_name = "setup-${var.openclaw.name_prefix}.yaml"
  }
}

module "openclaw" {
  source = "git::https://github.com/krakenhavoc/HomeLab.git//terraform/modules/compute/pm-cloudinit-vm?ref=v0.2.0"

  vm_name                        = var.openclaw.name_prefix
  vm_node_name                   = var.pve.host
  vm_description                 = var.openclaw.description
  vm_tags                        = var.openclaw.tags
  vm_bios                        = var.openclaw.bios
  clone_vm_id                    = data.proxmox_virtual_environment_vms.noble_template.vms[0].vm_id
  vm_cpu_cores                   = var.openclaw.cpu_cores
  vm_memory_mb                   = var.openclaw.memory_mb
  vm_disk_datastore_id           = var.vm_disk_datastore_id
  vm_disk_interface              = var.openclaw.disk_interface
  vm_disk_size                   = var.openclaw.os_disk_size
  vm_cloudinit_datastore_id      = var.vm_cloudinit_datastore_id
  vm_cloudinit_user_data_file_id = proxmox_virtual_environment_file.openclaw_cloudinit.id
  vm_network_bridge              = var.openclaw.network_bridge
  vm_vlan_id                     = var.openclaw.vlan_id
}

resource "proxmox_virtual_environment_file" "pwnbox_cloudinit" {
  provider     = pve
  content_type = "snippets"
  datastore_id = "snippets"
  node_name    = var.pve.host

  source_raw {
    data = templatefile("${path.module}/templates/setup-pwnbox.yaml.tftpl", {
      pwnbox_admin_username = var.pwnbox.admin_username
      pwnbox_hostname       = var.pwnbox.name_prefix
    })
    file_name = "setup-${var.pwnbox.name_prefix}.yaml"
  }
}

module "pwnbox" {
  source = "git::https://github.com/krakenhavoc/HomeLab.git//terraform/modules/compute/pm-cloudinit-vm?ref=v0.2.0"

  vm_name                        = var.pwnbox.name_prefix
  vm_node_name                   = var.pve.host
  vm_description                 = var.pwnbox.description
  vm_tags                        = var.pwnbox.tags
  vm_bios                        = var.pwnbox.bios
  clone_vm_id                    = data.proxmox_virtual_environment_vms.noble_template.vms[0].vm_id
  vm_cpu_cores                   = var.pwnbox.cpu_cores
  vm_memory_mb                   = var.pwnbox.memory_mb
  vm_disk_datastore_id           = var.vm_disk_datastore_id
  vm_disk_interface              = var.pwnbox.disk_interface
  vm_disk_size                   = var.pwnbox.os_disk_size
  vm_cloudinit_datastore_id      = var.vm_cloudinit_datastore_id
  vm_cloudinit_user_data_file_id = proxmox_virtual_environment_file.pwnbox_cloudinit.id
  vm_network_bridge              = var.pwnbox.network_bridge
  vm_vlan_id                     = var.pwnbox.vlan_id
}

# -----------------------------------------------------------------------------
# cmd_and_ctrl game server — production and develop preview
# -----------------------------------------------------------------------------
# Two VMs from one definition, behind cmd.labxp.io and cmd-dev.labxp.io.
#
# Both hostnames are deliberately ONE label under the zone. Cloudflare
# Universal SSL issues only labxp.io + *.labxp.io, and a wildcard matches a
# single label, so a nested name like dev.cmd.labxp.io has no certificate and
# fails the TLS handshake outright -- no HTTP, no useful error at the edge.
# Covering a nested name needs Advanced Certificate Manager. Keep new
# hostnames flat unless someone buys it.
#
# They differ only in hostname, fqdn, tokens and CMDCTRL_ENV. Paths, service
# name, service user and listen port are identical, so the cmd_and_ctrl CD
# pipeline deploys to both with the same recipe and only the target host
# changes. A preview environment whose deploy is shaped differently from the
# production deploy it rehearses is not rehearsing anything.
#
# Raw resource (not the pm-cloudinit-vm module) because each needs a second
# data disk for CMDCTRL_DATA_DIR (Scryfall dump + image cache).

locals {
  cmd_and_ctrl_environments = {
    prod = var.cmd_and_ctrl
    dev  = var.cmd_and_ctrl_dev
  }

  # Production's tunnel was created by hand in the Zero Trust dashboard and its
  # token arrives as a secret; importing a tunnel that is currently serving
  # traffic is a risk with no payoff. The develop tunnel is created below, so
  # its token comes from the provider and needs no secret at all.
  cmd_and_ctrl_tunnel_tokens = {
    prod = var.cmd_and_ctrl_tunnel_token
    dev  = data.cloudflare_zero_trust_tunnel_cloudflared_token.cmd_and_ctrl_dev.token
  }

  # Separate tokens on purpose: the preview environment exposes card spawning
  # and seat swapping to any admin session, so sharing production's token would
  # make a leak from the low-trust box a compromise of the live table.
  cmd_and_ctrl_admin_tokens = {
    prod = var.cmd_and_ctrl_admin_token
    dev  = var.cmd_and_ctrl_dev_admin_token
  }

  # Only production files bug reports. The preview environment is left empty,
  # which makes the template omit the env line entirely -- a low-trust box with
  # Issues:write on the production repo is not a trade worth making for a
  # button nobody uses in a preview.
  cmd_and_ctrl_github_tokens = {
    prod = var.cmd_and_ctrl_github_token
    dev  = ""
  }
}

# --- Cloudflare: develop tunnel, ingress and DNS -----------------------------
# config_src = "cloudflare" is load-bearing. Left at its default the connector
# expects a local config file and the ingress rules below are never applied,
# which presents as a tunnel that is healthy and returns 502.

resource "cloudflare_zero_trust_tunnel_cloudflared" "cmd_and_ctrl_dev" {
  account_id = var.cloudflare_account_id
  name       = var.cmd_and_ctrl_dev.name_prefix
  config_src = "cloudflare"
}

resource "cloudflare_zero_trust_tunnel_cloudflared_config" "cmd_and_ctrl_dev" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.cmd_and_ctrl_dev.id

  config = {
    ingress = [
      {
        hostname = var.cmd_and_ctrl_dev.fqdn
        # Caddy on the dev VM. It listens plain HTTP because Cloudflare
        # terminates TLS at the edge.
        service = "http://localhost:80"
      },
      # Cloudflare requires a catch-all rule with no hostname as the last entry.
      {
        service = "http_status:404"
      },
    ]
  }
}

resource "cloudflare_dns_record" "cmd_and_ctrl_dev" {
  zone_id = var.cloudflare_zone_id
  name    = var.cmd_and_ctrl_dev.fqdn
  type    = "CNAME"
  content = "${cloudflare_zero_trust_tunnel_cloudflared.cmd_and_ctrl_dev.id}.cfargotunnel.com"
  proxied = true
  # Proxied records must use TTL 1 ("automatic"); Cloudflare rejects anything else.
  ttl = 1
}

# --- Proxmox VMs -------------------------------------------------------------

resource "proxmox_virtual_environment_file" "cmd_and_ctrl_cloudinit" {
  for_each = local.cmd_and_ctrl_environments

  provider     = pve
  content_type = "snippets"
  datastore_id = "snippets"
  node_name    = var.pve.host

  source_raw {
    data = templatefile("${path.module}/templates/setup-cmd_and_ctrl.yaml.tftpl", {
      hostname       = each.value.name_prefix
      admin_username = each.value.admin_username
      fqdn           = each.value.fqdn
      cmdctrl_env    = each.value.cmdctrl_env
      admin_token    = local.cmd_and_ctrl_admin_tokens[each.key]
      tunnel_token   = local.cmd_and_ctrl_tunnel_tokens[each.key]
      github_token   = local.cmd_and_ctrl_github_tokens[each.key]
    })
    file_name = "setup-${each.value.name_prefix}.yaml"
  }
}

resource "proxmox_virtual_environment_vm" "cmd_and_ctrl" {
  for_each = local.cmd_and_ctrl_environments

  provider = pve

  name        = each.value.name_prefix
  node_name   = var.pve.host
  description = each.value.description
  tags        = sort(concat(["terraform"], each.value.tags))
  bios        = each.value.bios

  clone {
    vm_id = data.proxmox_virtual_environment_vms.noble_template.vms[0].vm_id
    full  = true
  }

  agent {
    enabled = true
    trim    = true
  }

  cpu {
    cores = each.value.cpu_cores
    type  = "x86-64-v2-AES"
  }

  memory {
    dedicated = each.value.memory_mb
  }

  # OS disk (cloned from template)
  disk {
    datastore_id = var.vm_disk_datastore_id
    interface    = "virtio0"
    iothread     = true
    discard      = "on"
    size         = each.value.os_disk_size
  }

  # Data disk for CMDCTRL_DATA_DIR — Scryfall dump + image cache.
  # cloud-init formats/mounts at /var/lib/cmd_and_ctrl.
  disk {
    datastore_id = var.vm_disk_datastore_id
    interface    = "virtio1"
    iothread     = true
    discard      = "on"
    size         = each.value.data_disk_size
    file_format  = "raw"
  }

  initialization {
    datastore_id = var.vm_cloudinit_datastore_id
    ip_config {
      ipv4 {
        address = "dhcp"
      }
    }
    user_data_file_id = proxmox_virtual_environment_file.cmd_and_ctrl_cloudinit[each.key].id
  }

  network_device {
    bridge  = each.value.network_bridge
    vlan_id = each.value.vlan_id
  }

  serial_device {}

  vga {
    type = "std"
  }

  operating_system {
    type = "l26"
  }

  # Cloud-init is first-boot only, so a changed snippet is not a reason to
  # rebuild a running VM -- and without this it is. Editing the template
  # replaces proxmox_virtual_environment_file (source_raw forces replacement),
  # which makes its id unknown at plan time even when the resulting id string
  # is identical, which propagates into user_data_file_id here and forces the
  # VM to be replaced. That destroyed the production VM and its data disk on
  # 2026-09-10.
  #
  # The cost of ignoring it: a template edit no longer reaches an existing
  # host. Changes to the env file or Caddyfile must be delivered by the
  # cmd_and_ctrl CD pipeline, or the VM tainted deliberately to rebuild it.
  lifecycle {
    ignore_changes = [initialization]
  }
}

# The single cmd_and_ctrl VM became a for_each over environments. These tell
# Terraform the production VM and its cloud-init snippet moved address rather
# than being destroyed and rebuilt.
#
# CHECK THE PLAN BEFORE APPLYING: it must report 0 to destroy. A plan that
# wants to destroy proxmox_virtual_environment_vm.cmd_and_ctrl means a moved
# block did not match, and applying it would take production down and lose the
# data disk.
moved {
  from = proxmox_virtual_environment_file.cmd_and_ctrl_cloudinit
  to   = proxmox_virtual_environment_file.cmd_and_ctrl_cloudinit["prod"]
}

moved {
  from = proxmox_virtual_environment_vm.cmd_and_ctrl
  to   = proxmox_virtual_environment_vm.cmd_and_ctrl["prod"]
}

# -----------------------------------------------------------------------------
# Windows 11 VM
# -----------------------------------------------------------------------------
# Uses a raw resource instead of the cloud-init module since Windows requires
# ISO-based installation with UEFI, TPM 2.0, and VirtIO driver loading.
# Post-apply steps:
#   1. Attach virtio-win.iso as a second CD-ROM via Proxmox UI (Hardware > Add > CD/DVD)
#   2. Boot the VM and install Windows via the Proxmox console
#   3. During disk selection, load driver: vioscsi\w11\amd64 from the VirtIO CD
#   4. After install, run virtio-win-gt-x64.msi from the VirtIO CD for all drivers + QEMU Guest Agent

resource "proxmox_virtual_environment_vm" "windows11" {
  provider = pve

  name        = var.windows11.name_prefix
  node_name   = var.pve.host
  description = var.windows11.description
  tags        = sort(concat(["terraform"], var.windows11.tags))
  on_boot     = false
  bios        = "ovmf"
  machine     = "q35"

  operating_system {
    type = "win11"
  }

  cpu {
    type    = "host"
    cores   = var.windows11.cpu_cores
    sockets = 1
    flags   = ["+nested-virt"]
  }

  memory {
    dedicated = var.windows11.memory_mb
    floating  = 0
  }

  tpm_state {
    version      = "v2.0"
    datastore_id = var.vm_disk_datastore_id
  }

  efi_disk {
    datastore_id      = var.vm_disk_datastore_id
    file_format       = "raw"
    type              = "4m"
    pre_enrolled_keys = true
  }

  # OS disk — VirtIO SCSI for best performance
  disk {
    interface    = "scsi0"
    datastore_id = var.vm_disk_datastore_id
    size         = var.windows11.os_disk_size
    file_format  = "raw"
    cache        = "writeback"
    discard      = "on"
    iothread     = true
    ssd          = true
  }

  scsi_hardware = "virtio-scsi-single"

  # Windows 11 installation ISO
  cdrom {
    file_id   = "local:iso/win11-latest.iso"
    interface = "ide0"
  }

  agent {
    enabled = true
    type    = "virtio"
    trim    = true
  }

  network_device {
    model   = "virtio"
    bridge  = var.windows11.network_bridge
    vlan_id = var.windows11.vlan_id
  }

  vga {
    type   = "virtio"
    memory = 64
  }

  stop_on_destroy = true
}
