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
| Grafana | Dashboards. Anonymous access is off. | https://grafana.labxp.io through the gateway, or `:3000` directly; LAN only |
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
5. **Heartbeat.** Every 5 minutes, while Prometheus and Alertmanager are both ready, this VM writes the current Unix time (decimal seconds) to the repo-level Actions variable `CMDCTRL_MONITORING_HEARTBEAT` on `krakenhavoc/cmd_and_ctrl`. That repo's GitHub cron alerts when the value is more than 20 minutes old.

## Deploying

The order matters, and each step is a merge of a reviewed plan:

1. Merge the `tfc` change that adds the `cmd-and-ctrl-monitoring-prd` workspace (local execution).
2. Set the address in `terraform/deployments/cmd-and-ctrl-monitoring/env/prd/terraform.tfvars`. The gateway, DNS servers, search domain and `lan_cidrs` are already filled in.
   - The VM's MAC is pinned (`mac_address`). Reserve an address for it on the router, on VLAN 200 and outside the DHCP pool.
   - Put that address in `ipv4_address` as `a.b.c.d/24`. The plan fails while the `192.0.2.x` placeholder remains.
   - The static address and the reservation must agree.
   - Adjust `lan_cidrs` if Grafana is viewed from somewhere else, such as a VPN range.
3. Create five Bitwarden secrets in the prd project and map their ids with `.github/scripts/bws-map.sh` (the command is in `env/prd/secrets.env`):
   - `CMDCTRL_MONITORING_GRAFANA_ADMIN_PASSWORD`: 16 characters or more, no single quote.
   - `CMDCTRL_MONITORING_DISCORD_WEBHOOK_URL`: the channel's webhook.
   - `CMDCTRL_MONITORING_PUSH_HASH_PROD` and `CMDCTRL_MONITORING_PUSH_HASH_DEV`: generate each from that environment's push password with `docker run --rm caddy:2.11.6-alpine caddy hash-password --plaintext '<password>'`.
   - `CMDCTRL_MONITORING_HEARTBEAT_TOKEN`: a fine-grained personal access token, created as described under [Heartbeat](#heartbeat).
4. On the router, allow the flows the host firewall expects:
   - the cmd_and_ctrl VMs to this VM on TCP 9091 and 3101;
   - the lab gateway (pfe, 192.168.201.14) to TCP 3000, for https://grafana.labxp.io;
   - any direct Grafana viewers to TCP 3000;
   - this VM out to HTTPS: GitHub, Docker Hub, and the two `/healthz` URLs.

   Add the Pi-hole A record `grafana.labxp.io` -> `192.168.201.14` on both resolvers (192.168.10.11 and .12). The gateway's site and portal card ship separately in `gateway/`.
5. Read the plan: one snippet file and one VM to add, nothing else. Then merge.
6. In cmd_and_ctrl, set `CMDCTRL_MONITORING_URL` to `http://<address>` and the two push passwords. Its CD then starts Alloy on the app hosts.

First boot formats and mounts the data disk, installs Docker, loads the firewall, clones this repository and starts `monitoring-sync`. That pulls the images and starts the stack, then enables `cmdctrl-config-sync` and `cmdctrl-heartbeat`. Check progress on the console with `cloud-init status --long` and `journalctl -u monitoring-sync`.

## Reaching Grafana

Open **https://grafana.labxp.io** from the LAN or the VPN and sign in as `admin`. It is also on the portal.
- **How it gets there:** the lab gateway (pfe, `gateway/caddy/Caddyfile`) terminates TLS and proxies to this VM on `:3000`.
- **Grafana's `root_url`** is set to that name, so links it generates (alerts, shares, Discord messages) point at the gateway.
- **Name resolution:** the name needs a Pi-hole A record on both resolvers.
- **Network:** the router must allow pfe to reach this VM on TCP 3000. pfe is also in `lan_cidrs`.

Direct `http://192.168.200.11:3000` (the `grafana_url` output) keeps working from `lan_cidrs` and is the recovery path when the gateway is down. Login and editing work there too, because Grafana's origin check compares against the request's own host, not `root_url`. Only absolute links point at the gateway name.

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

## Heartbeat

Nothing outside the house can reach this VM, so it reports out instead.

`cmdctrl-heartbeat.timer` fires every 5 minutes, with up to 30 s of random delay. Each run:
1. checks Prometheus and Alertmanager `/-/ready` through `docker exec`, on each container's own loopback (no host ports);
2. if both are ready, sends `PATCH /repos/krakenhavoc/cmd_and_ctrl/actions/variables/CMDCTRL_MONITORING_HEARTBEAT` with the current epoch seconds, and on a 404 creates the variable with `POST /repos/krakenhavoc/cmd_and_ctrl/actions/variables`;
3. on success, writes `cmdctrl_monitoring_heartbeat_last_success_timestamp_seconds` to the textfile directory.

cmd_and_ctrl's GitHub cron alerts when the variable is more than 20 minutes old. That covers this VM dying, the stack being unready, and the whole node going down.

**The token** is a fine-grained personal access token. Create it under GitHub → Settings → Developer settings → Fine-grained tokens:
- **Resource owner:** `krakenhavoc`.
- **Repository access:** only `krakenhavoc/cmd_and_ctrl`.
- **Repository permissions:** **Variables: Read and write**, and nothing else (GitHub adds Metadata: Read by itself).
- **Expiry:** your choice. When the token expires, the heartbeat stops silently and the cron reports "heartbeat lost". That is the intended failure: renew the token and rotate it as below.

cloud-init writes the token to `/etc/monitoring/heartbeat_token` (root, 0600). It never appears on a command line or in a log: curl reads the header from a 0600 file under `/run`, and only HTTP status codes are logged. With no token file, each run logs that and exits without a beat.

Check it with `journalctl -u cmdctrl-heartbeat`, or `gh variable get CMDCTRL_MONITORING_HEARTBEAT --repo krakenhavoc/cmd_and_ctrl`.

## Rotating a secret

Changing a Bitwarden value does not reach the running VM. Rotate it on the host as well.

- **Grafana admin password:** run `docker exec grafana grafana cli admin reset-admin-password '<new>'`, then update `/etc/monitoring/grafana.env` so a rebuilt database gets the same password.
- **Discord webhook:** edit `/etc/monitoring/discord_webhook_url` (one line, no trailing newline), then run `docker kill --signal HUP alertmanager`.
- **Push credential:** put the new hash in `/etc/monitoring/caddy.env`, single-quoted, and run `docker compose -f /opt/monitoring/live/docker-compose.yaml up -d caddy`. Then update the matching password in cmd_and_ctrl.
- **Heartbeat token:** run `sudo install -m 0600 /dev/stdin /etc/monitoring/heartbeat_token`, paste the new token and press Ctrl-D. This keeps it out of shell history, and a trailing newline is fine. Then run `sudo systemctl start cmdctrl-heartbeat` and check its log. Update the Bitwarden secret too, so a rebuild gets the new token.

## Backups

**This VM is not backed up**; ADR 0123 §6 accepts that. Everything in Grafana that matters is provisioned from files, so a rebuild loses only metric and log history. The history of games and users stays in cmd_and_ctrl's own SQLite database, which is backed up off-node. Save any Scratch dashboard worth keeping to cmd_and_ctrl.

To rebuild on purpose, first remove `prevent_destroy` from the VM resource.

## Known gaps

- The VM is watched from outside only through the heartbeat. When the heartbeat is lost, cmd_and_ctrl's cron can't tell a dead VM from an expired token or a broken GitHub path; the log on this VM can.
- This VM shares the Proxmox node with what it monitors.
- Alloy runs in a container, so the `node` network counters are the container's, not the VM's.

Internal addresses and credential values are intentionally kept out of this public guide.
