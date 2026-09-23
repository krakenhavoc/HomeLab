# One-time adoption from the lab workspace (lab forgets them with removed
# blocks in the same change). Delete after apply.

locals {
  adopt = {
    prod = { vm_id = 112 }
    dev = {
      vm_id      = 113
      tunnel_id  = "9c5a2dd4-816e-4924-b26b-c4d3eb2941fe"
      dns_record = "60f4d18686855b6d5846f2ecc329fb44"
    }
  }[var.cmd_and_ctrl.cmdctrl_env]

  adopt_tunnel = var.cmd_and_ctrl.manage_tunnel ? toset(["this"]) : toset([])
}

import {
  to = proxmox_virtual_environment_vm.this
  id = "${var.pve.host}/${local.adopt.vm_id}"
}

# source_raw can't be read back, so the snippet is rewritten once. The VM
# ignores initialization, so this doesn't touch it.
import {
  to = proxmox_virtual_environment_file.cloudinit
  id = "${var.pve.host}/snippets:snippets/setup-${var.cmd_and_ctrl.name_prefix}.yaml"
}

import {
  to = cloudflare_r2_bucket.backup
  id = "${var.cloudflare_account_id}/${var.cmd_and_ctrl.backup_bucket}/default"
}

# cloudflare_r2_bucket_lifecycle has no import; it is recreated with the same
# rule (a PUT of the bucket's lifecycle config).

import {
  for_each = local.adopt_tunnel
  to       = cloudflare_zero_trust_tunnel_cloudflared.this[0]
  id       = "${var.cloudflare_account_id}/${local.adopt.tunnel_id}"
}

import {
  for_each = local.adopt_tunnel
  to       = cloudflare_zero_trust_tunnel_cloudflared_config.this[0]
  id       = "${var.cloudflare_account_id}/${local.adopt.tunnel_id}"
}

import {
  for_each = local.adopt_tunnel
  to       = cloudflare_dns_record.this[0]
  id       = "${var.cloudflare_zone_id}/${local.adopt.dns_record}"
}
