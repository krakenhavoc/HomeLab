data "proxmox_virtual_environment_vms" "noble_template" {
  provider  = pve
  node_name = var.pve.host

  filter {
    name   = "name"
    values = ["noble-template"]
  }
}

# Connector token for the develop tunnel. In provider v5 the tunnel resource no
# longer exposes tunnel_token; it is fetched separately.
data "cloudflare_zero_trust_tunnel_cloudflared_token" "cmd_and_ctrl_dev" {
  account_id = var.cloudflare_account_id
  tunnel_id  = cloudflare_zero_trust_tunnel_cloudflared.cmd_and_ctrl_dev.id
}
