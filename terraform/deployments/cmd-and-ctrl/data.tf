data "proxmox_virtual_environment_vms" "noble_template" {
  provider  = pve
  node_name = var.pve.host

  filter {
    name   = "name"
    values = ["noble-template"]
  }
}

# Connector token for the managed (dev) tunnel. Provider v5 no longer exposes it
# on the tunnel resource.
data "cloudflare_zero_trust_tunnel_cloudflared_token" "this" {
  count = var.cmd_and_ctrl.manage_tunnel ? 1 : 0

  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.this[0].id
}
