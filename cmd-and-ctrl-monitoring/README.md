# cmd_and_ctrl monitoring

This directory is the runtime configuration for the monitoring VM of [cmd_and_ctrl](https://github.com/krakenhavoc/cmd_and_ctrl). The design is that project's [ADR 0123](https://github.com/krakenhavoc/cmd_and_ctrl/blob/main/docs/decisions/0123-monitoring-metrics-logs-dashboards-and-alerts.md). The VM is LAN-only, with no tunnel and no public DNS.

| Piece | Owner |
| --- | --- |
| VM, data disk, address, firewall, first-boot secrets | `terraform/deployments/cmd-and-ctrl-monitoring` through `deploy.yaml` |
| Prometheus, Alertmanager, Loki, Grafana, blackbox_exporter, Caddy, Alloy | `cmd-and-ctrl-monitoring/docker-compose.yaml` and the per-service directories here |
| Reconcile loops | `cmd-and-ctrl-monitoring/bootstrap/` |
| Alert rules and dashboards | `deploy/monitoring/` in the cmd_and_ctrl repository, pulled from `main` |
| What the app hosts send (Alloy on each cmd_and_ctrl VM) | the cmd_and_ctrl repository's CD |

## What runs

All services run as one Compose project, `monitoring`, in `/opt/monitoring/live`. Every image is pinned by tag and digest. Data lives on the 80 GB data disk at `/var/lib/monitoring`.

| Service | Role | Reachable |
| --- | --- | --- |
| Prometheus | Metrics: remote-write receiver, 1 year or 60 GB, 30 s scrapes, alert rules from cmd_and_ctrl | Compose network only |
| Alertmanager | Discord notifications, grouped by `alertname` and `env`, repeated every 4 h, resolutions sent | Compose network only |
| Loki | Logs, 30 days, retention enforced by the compactor | Compose network only |
| Grafana | Dashboards. Anonymous access is off. | `:3000`, LAN only |
| blackbox_exporter | Probes `https://cmd.labxp.io/healthz` (`env="prod"`) and `https://cmd-dev.labxp.io/healthz` (`env="dev"`) as job `blackbox` | Compose network only |
| Caddy | The two push endpoints, with basic auth | `:9091` and `:3101`, LAN only |
| Alloy | This VM's host metrics and the config-sync textfile, sent as `job="node"`, `env="monitoring"` | Compose network only |

## Contracts with cmd_and_ctrl

The cmd_and_ctrl repository builds against these. Change them only together with that repository.

1. **Push endpoints.** These use HTTP basic auth with one user per app host, `prod` and `dev`. Caddy proxies only these two paths, and only for `POST`; anything else gets a 404.
   - `http://<address>:9091/api/v1/write` is Prometheus remote write.
   - `http://<address>:3101/loki/api/v1/push` is Loki push.

   The passwords are cmd_and_ctrl's `CMDCTRL_MONITORING_PUSH_PASSWORD` in its `prod` and `dev` environments. This VM holds only their bcrypt hashes.
2. **Grafana datasource UIDs** are `prometheus` and `loki`. There is also `alertmanager`.
3. **Config sync.** `deploy/monitoring/` is read from `krakenhavoc/cmd_and_ctrl`, branch `main`, every 10 minutes:
   - `rules/*.yml` are Prometheus rule files. `rules/tests/` is ignored.
   - `dashboards/*.json` are Grafana dashboards. They load into the read-only `cmd_and_ctrl` folder; `Scratch` is the editable folder for drafts.
   - A missing `deploy/monitoring/` counts as a success with nothing to load.
   - The sync writes `cmdctrl_monitoring_sync_last_success_timestamp_seconds`.
4. **Labels.** App-host series arrive with `env` (`prod`/`dev`) and `host` set by their Alloy. The server's job is `cmdctrl-server` and host metrics are `node`. This VM's own series carry `env="monitoring"`.

## Deploying

The order matters, and each step is a merge of a reviewed plan:

1. Merge the `tfc` change that adds the `cmd-and-ctrl-monitoring-prd` workspace (local execution).
2. In `terraform/deployments/cmd-and-ctrl-monitoring/env/prd/terraform.tfvars`, replace the `192.0.2.x` placeholders with the real values. The plan fails while any placeholder remains.
   - `ipv4_address`: a free address outside the VLAN's DHCP pool, in CIDR form.
   - `ipv4_gateway` and `dns_servers`.
   - `lan_cidrs`: the cmd_and_ctrl VLAN, plus the client and VPN ranges Grafana is opened from.
3. Create four Bitwarden secrets in the prd project and map their ids with `.github/scripts/bws-map.sh` (the command is in `env/prd/secrets.env`):
   - `CMDCTRL_MONITORING_GRAFANA_ADMIN_PASSWORD`: 16 characters or more, no single quote.
   - `CMDCTRL_MONITORING_DISCORD_WEBHOOK_URL`: the channel's webhook.
   - `CMDCTRL_MONITORING_PUSH_HASH_PROD` and `CMDCTRL_MONITORING_PUSH_HASH_DEV`: generate each from that environment's push password with `docker run --rm caddy:2.11.6-alpine caddy hash-password --plaintext '<password>'`.
4. On the router, allow the flows the host firewall expects:
   - the cmd_and_ctrl VMs to this VM on TCP 9091 and 3101;
   - the Grafana viewers to TCP 3000;
   - this VM out to HTTPS: GitHub, Docker Hub, and the two `/healthz` URLs.
5. Read the plan: one snippet file and one VM to add, nothing else. Then merge.
6. In cmd_and_ctrl, set `CMDCTRL_MONITORING_URL` to `http://<address>` and the two push passwords. Its CD then starts Alloy on the app hosts.

First boot formats and mounts the data disk, installs Docker, loads the firewall, clones this repository and starts `monitoring-sync`. That pulls the images and starts the stack, then enables `cmdctrl-config-sync`. Check progress on the console with `cloud-init status --long` and `journalctl -u monitoring-sync`.

## Reaching Grafana

Open `http://<address>:3000` from the LAN or the VPN and sign in as `admin`. The address is the `grafana_url` output of the deployment.

The `cmd_and_ctrl` folder is provisioned and read-only. To change a dashboard:
1. Save a copy into `Scratch` and edit it there.
2. Export the JSON.
3. Open a pull request in cmd_and_ctrl.

It goes live within 10 minutes of the change reaching cmd_and_ctrl's `main`.

## How changes reach the host

- **Stack** (this directory): `monitoring-sync.timer`, every 10 minutes, fetches HomeLab `main`.
  - It checks each incoming config with the image that will run it: `promtool check config`, `amtool check-config`, `loki -verify-config`, blackbox `--config.check`, `caddy validate` and `alloy fmt`.
  - Only then does it copy the directory into `/opt/monitoring/live` and reconcile Compose.
  - Prometheus, Alertmanager and blackbox are reloaded; the other services restart if their directory changed.
  - A failed check leaves the running stack untouched and shows in `systemctl status monitoring-sync`.
- **Image upgrades:** change the tag and the digest together in `docker-compose.yaml`. The digest comes from `docker buildx imagetools inspect <image>:<tag>`.
- **Rules and dashboards** (cmd_and_ctrl): `cmdctrl-config-sync.timer`, every 10 minutes.
  - It runs a sparse, shallow clone of `deploy/monitoring/`.
  - It checks the rules with `promtool check rules`, using the running Prometheus image, and JSON-parses every dashboard.
  - It then swaps the `current` symlink under `/var/lib/monitoring/cmdctrl-config` and reloads Prometheus with `POST /-/reload`.
  - On any failure, the previous set stays live and `cmdctrl_monitoring_sync_last_success_timestamp_seconds` stops advancing; cmd_and_ctrl's `MonitoringConfigSyncFailing` alert reads it.

The VM ignores cloud-init changes, so editing the Terraform template only affects a rebuilt host.

## Rotating a secret

Changing a Bitwarden value does not reach the running VM. Rotate it on the host as well.

- **Grafana admin password:** run `docker exec grafana grafana cli admin reset-admin-password '<new>'`, then update `/etc/monitoring/grafana.env` so a rebuilt database gets the same password.
- **Discord webhook:** edit `/etc/monitoring/discord_webhook_url` (one line, no trailing newline), then run `docker kill --signal HUP alertmanager`.
- **Push credential:** put the new hash in `/etc/monitoring/caddy.env`, single-quoted, and run `docker compose -f /opt/monitoring/live/docker-compose.yaml up -d caddy`. Then update the matching password in cmd_and_ctrl.

## Backups

**This VM is not backed up**; ADR 0123 §6 accepts that. Everything in Grafana that matters is provisioned from files, so a rebuild loses only metric and log history. The history of games and users stays in cmd_and_ctrl's own SQLite database, which is backed up off-node. Save any Scratch dashboard worth keeping to cmd_and_ctrl.

To rebuild on purpose, first remove `prevent_destroy` from the VM resource.

## Known gaps

- Nothing watches this VM from outside. If it dies, alerts stop silently; cmd_and_ctrl's GitHub Actions uptime check still watches the sites.
- This VM shares the Proxmox node with what it monitors.
- Alloy runs in a container, so the `node` network counters are the container's, not the VM's.

Internal addresses and credential values are intentionally kept out of this public guide.
