# Gateway configuration

Runtime configuration for the lab gateway on `pfe` (192.168.201.14): Caddy
terminating TLS in front of a Homepage portal and the private frontends.

Design and rationale live in [`docs/gateway.md`](../docs/gateway.md). This
directory is the config itself.

## How config reaches the host

`gateway-sync` runs on `pfe` every minute, fetches this repo, validates the
incoming Caddyfile against the running Caddy, copies `gateway/` to
`/opt/gateway/live/` and runs `docker compose up -d`.

**Push to `main` and the gateway follows within the minute.** No Terraform, no
apply, no VM rebuild.

That indirection is not decoration. `pm-cloudinit-vm` has no
`ignore_changes` on `initialization`, so editing a cloud-init template
*replaces the VM* — the mechanism that destroyed the `cmd_and_ctrl` VM on
2026-09-10. A reverse proxy's config changes far too often to pay a rebuild
each time, and each rebuild would discard Caddy's certificate store. Let's
Encrypt allows 5 duplicate certificates per week, so a few afternoons of
iteration through cloud-init would end with no working TLS at all.

Terraform owns the VM and the secrets. This directory owns everything else.

## Adding a service

Four steps, none of them Terraform:

1. **Caddyfile** — copy a block, point it at the upstream:

   ```caddyfile
   plex.labxp.io {
       import tls_cloudflare
       reverse_proxy 192.168.10.x:32400
   }
   ```

2. **DNS** — a **plain host record** on **both** Pi-holes (192.168.10.11 and
   .12) for `plex.labxp.io` → `192.168.201.14`. Both, not one: a single entry
   means the name stops resolving whenever that Pi-hole reboots.

   Never a dnsmasq `address=/labxp.io/192.168.201.14` line. That matches every
   subdomain, so it would swallow `cmd.labxp.io` (live and public) and
   `pve.labxp.io` (the endpoint every Terraform run here uses). A host record
   matches the exact name only.

3. **Firewall** — allow `pfe` → the upstream's address and port. `pfe` is on
   VLAN 201 and most targets are not, so this is an inter-VLAN rule. Keep it
   per-destination-and-port; never `VLAN 201 → any`.

4. **Portal** — add it to `homepage/services.yaml` so it appears on the splash
   page.

Push. Done.

Do **not** add `pve.labxp.io`. That name is the Proxmox API endpoint the
`bpg/proxmox` provider uses from CI; repointing it would route every Terraform
run in this repo through Caddy, turning a proxy hiccup into a CI outage across
every deployment. Browser access uses `proxmox.labxp.io` instead.

## Secrets

`/etc/gateway/caddy.env` holds `CF_DNS_API_TOKEN` and is written once by
cloud-init from a Terraform variable. It is **not** in this repo, which is
public.

Rotating it is a Terraform change plus a rebuild, or — faster — editing the
file on the host and `docker compose restart caddy`.

## Troubleshooting

**Blank page or "Host validation failed"** — `HOMEPAGE_ALLOWED_HOSTS` in
`docker-compose.yaml` must list the browser-facing hostname (`labxp.io`), not
the container name or the proxy's address. Mandatory since Homepage v1.0 and
the most common first-deploy failure.

**Certificate never issues** — check the Cloudflare token first:

```bash
docker exec caddy env | grep CF_DNS      # is it even present
docker logs caddy 2>&1 | grep -i acme
```

A Cloudflare **401 code 10000** is an invalid, revoked or expired token — *or*
a valid one whose Client IP Address Filter excludes the caller. That last case
took down the lab pipeline on 2026-09-21 and is invisible from the dashboard.
**403 code 10000** is a token missing a permission. The token needs
`Zone:DNS:Edit` and `Zone:Zone:Read` on `labxp.io`.

**Name does not resolve** — the Pi-hole records are manual and easy to add to
only one of the two.

**Config changes not appearing** — `systemctl status gateway-sync` and
`journalctl -u gateway-sync -n 50`. A rejected Caddyfile logs the validation
error and leaves the previous config serving.

**Everything is down** — Caddy is the only container binding ports, so a Caddy
failure takes every name with it. Services remain reachable at their
`IP:port`; the gateway is a convenience layer, not a dependency.

## The apex

The portal is served at `labxp.io` itself, not a subdomain. Both Pi-holes
answer that exact name with `192.168.201.14`, which means **anything published
at the apex on the public internet is unreachable from inside the lab**. That
is accepted, not overlooked. Subdomains are unaffected — `cmd.labxp.io` still
resolves publicly — as long as the Pi-hole entries stay plain host records.
