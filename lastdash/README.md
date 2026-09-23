# LastDash

Runtime configuration for [LastDash](https://github.com/krakenhavoc/lastdash)
on the `lastdash-prod` VM, served at **https://lastdash.labxp.io** through the
gateway. LAN/VPN only — see *Access* below.

| Piece | Where |
| --- | --- |
| VM, secrets | `terraform/deployments/lastdash` (applied by `deploy.yaml`) |
| Compose stack (web, api, Postgres 16, Redis 7) | `lastdash/docker-compose.yaml` |
| Reconcile loop | `lastdash/bootstrap/lastdash-sync` + timer (every 5 min) |
| TLS + routing | `gateway/caddy/Caddyfile`, block `lastdash.labxp.io` |
| Portal card | `gateway/homepage/services.yaml`, group *Apps* |
| Images | `ghcr.io/krakenhavoc/lastdash-{api,web}`, built by the app repo |

## How it updates

Same shape as the gateway: **push, and the host follows.**

- **Config** (this directory): `lastdash-sync` fetches `main`, validates the
  compose file and runs `docker compose up -d` — within ~5 minutes.
- **App**: a merge to LastDash `main` builds new `:latest` images; the next
  sync pulls them. To hold a version, set `LASTDASH_TAG=<git sha>` in
  `/etc/lastdash/env`.
- **VM / secrets**: Terraform, but only for creation. The VM ignores
  cloud-init changes (`lifecycle.ignore_changes = [initialization]`) because
  it holds the database — so editing a secret in GitHub does **not** reach a
  running host. Edit `/etc/lastdash/env` on the host and run
  `sudo systemctl start lastdash-sync`.

## First deploy checklist

1. GitHub environment **`prd`** on this repo with secrets
   `LASTDASH_TOKEN_ENCRYPTION_SECRET` (the dev value — see *Data*),
   `LASTDASH_NEXTAUTH_SECRET`, `LASTDASH_POSTGRES_PASSWORD`,
   `LASTDASH_GHCR_TOKEN` (classic PAT, `read:packages` only).
2. Terraform Cloud workspace **`lastdash-prd`** in `LabXPIO` (managed in `terraform/deployments/tfc`),
   **execution mode: Local** (the runner reaches Proxmox over SSH).
3. Firewall: a **static DHCP lease** on VLAN 201 for MAC
   `BC:24:11:00:02:50` (pinned in `env/prd/terraform.tfvars`), and
   that address as the upstream in the Caddyfile block. pfe → the VM is
   same-VLAN, no rule needed.
4. The VM gets its resolvers from the lease; make sure VLAN 201 DHCP clients
   can reach them (as they already do for other DHCP hosts there).
5. Pi-hole: host record `lastdash.labxp.io` → `192.168.201.14` on **both**
   Pi-holes.
6. Merge. Terraform creates the VM; cloud-init installs Docker, logs in to
   GHCR and starts the sync.

## Data

Prod starts from a copy of the dev database, so existing Slack/Teams
connections keep working. That only works because
`LASTDASH_TOKEN_ENCRYPTION_SECRET` equals the dev API's
`TOKEN_ENCRYPTION_SECRET` — stored tokens are encrypted with it.

```bash
# dev (inside the devcontainer)
pg_dump -h postgres -U lastdash -Fc lastdash > /tmp/lastdash.dump
scp /tmp/lastdash.dump lastdash@<vm>:/tmp/

# on the VM
cd /opt/lastdash/live
sudo docker compose --env-file /etc/lastdash/env stop api web
sudo docker compose --env-file /etc/lastdash/env exec -T postgres \
  pg_restore -U lastdash -d lastdash --clean --if-exists --no-owner < /tmp/lastdash.dump
sudo docker compose --env-file /etc/lastdash/env start api web
rm /tmp/lastdash.dump
```

## Access

LastDash has no real login yet: one dev user, and its API trusts an
`X-User-Id` header. It is safe only because the gateway is LAN/VPN-only.
**Do not publish this name** (no Cloudflare Tunnel, no public DNS) until the
app has real authentication.

Browser-session connect needs the LastDash companion extension ≥ 0.2.0, which
knows `https://lastdash.labxp.io`.
