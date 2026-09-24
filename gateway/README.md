# Gateway configuration

This directory is the runtime configuration for the internal gateway: Caddy terminates TLS, Homepage provides the portal, and Redlib runs behind the proxy.

The architecture and security decisions are documented in [Gateway and internal portal](../docs/gateway.md). This page covers day-to-day changes to the configuration itself.

## Contents

| Path | Purpose |
| --- | --- |
| `docker-compose.yaml` | Gateway containers, networks, volumes, and security settings |
| `caddy/Caddyfile` | Internal names, TLS policy, and upstream routes |
| `homepage/` | Portal layout, services, bookmarks, and widgets |
| `assets/` | Static portal assets |
| `bootstrap/` | Host-side sync service and timer |
| `redlib.env` | Non-secret Redlib settings |

## How changes reach the host

The host periodically fetches `main`, validates the candidate Caddyfile, copies the gateway configuration into its live directory, and reconciles the Compose project.

That pull model keeps inbound management access out of CI. It also prevents routine proxy edits from entering cloud-init, where a changed first-boot snippet can cause a VM replacement.

A failed Caddy validation leaves the last working configuration in service. Merging is still a production action: validate locally and review the route, DNS, and firewall implications first.

## Add a proxied service

Every service needs four coordinated changes:

1. Add an explicit Caddy route to the stable internal upstream.
2. Add the browser-facing name to internal DNS on every resolver clients may use.
3. Permit only the required gateway-to-upstream traffic.
4. Add a Homepage entry if the service belongs in the portal.

Use one host record per service. Do not add a zone-wide DNS wildcard, because it can shadow public applications and control-plane names.

Keep automation endpoints separate from human-facing proxy names. CI should not depend on the gateway it is responsible for updating.

## Portal widgets

Widget credentials come from the host environment and are referenced in Homepage configuration with its variable syntax:

```yaml
key: "{{HOMEPAGE_VAR_SERVICE_TOKEN}}"
```

Never place the value in this repository. Widgets should use read-only credentials wherever the upstream supports them, and the portal should remain useful when a widget credential is absent.

Homepage receives Docker status through the restricted socket proxy defined in `docker-compose.yaml`. Do not replace it with a direct socket mount into the web application.

## Static assets

Portal assets belong in `assets/`, which is mounted into Homepage's public asset directory. Keep images small enough for the repository's large-file check and reference them with an `/assets/` URL from `homepage/settings.yaml`.

## Change checklist

- [ ] The Caddyfile validates.
- [ ] The upstream is stable and reachable from the gateway.
- [ ] Internal DNS uses an explicit record on every resolver.
- [ ] Firewall access is limited to the required destination and service.
- [ ] No credential or internal inventory detail was added to tracked files.
- [ ] Direct recovery access remains available.
- [ ] The portal still works when optional widgets fail.

## Troubleshooting

### A configuration change does not appear

Inspect the host sync service and its recent logs. A rejected Caddyfile should be visible there while the previous configuration continues serving.

### The portal reports host validation errors

Confirm Homepage's allowed-host configuration matches the browser-facing name. Do not weaken the setting to a wildcard.

### A certificate is not issued

Check the Caddy logs, DNS provider authentication, zone permissions, and resolver visibility. Report error codes without printing tokens or environment files.

### One service fails while others work

Test the upstream directly from the gateway, then check its specific Caddy route, DNS record, and firewall path.

### Every gateway name fails

Check the gateway host, Caddy container, certificate volumes, and internal DNS. The backing services should remain reachable through their direct recovery paths.

Internal names, addresses, network identifiers, firewall rules, and credential identifiers are intentionally left out of this public guide.
