# Gateway: Portal and Internal Reverse Proxy

Status: **in progress.** The custom Caddy image (Phase 1) is built and
verified. `v0.3.0` of `pm-cloudinit-vm` is tagged, which unblocks pinning
`pfe`'s address. The stack itself is not yet deployed.

A single entry point to the lab: an attractive splash page listing every
internal service, and a reverse proxy in front of it so everything is reached
by a real DNS name over real HTTPS instead of a memorised `IP:port`.

## Table of Contents

- [Decisions](#decisions)
- [Architecture](#architecture)
- [Why config does not live in cloud-init](#why-config-does-not-live-in-cloud-init)
- [TLS without exposing anything](#tls-without-exposing-anything)
- [DNS](#dns)
- [Firewall](#firewall)
- [Secrets](#secrets)
- [Phases](#phases)
- [Facts required before implementation](#facts-required-before-implementation)
- [Risks and trade-offs](#risks-and-trade-offs)
- [Rejected alternatives](#rejected-alternatives)

## Decisions

| Decision | Choice | Consequence |
|----------|--------|-------------|
| Reach | LAN + VPN only | Nothing new is published to the internet. Browsers still get trusted certs. |
| Portal | [Homepage](https://gethomepage.dev) | Config is YAML in this repo, so the portal is reproducible from a rebuild. |
| Placement | Existing `pfe` host | No new VM, no new deployment directory. Couples the portal to the frontends host. |
| Naming | Flat — `plex.labxp.io` | Matches `pve.labxp.io` / `cmd.labxp.io`. Stays Universal-SSL-compatible if ever published. |

The placement choice is the one carrying the most weight. `pfe`
("Private Frontends Host", VLAN 201) exists today to run RedLib and nothing
else. Adding the gateway to it means the portal, the proxy and RedLib share a
fate: a reboot of that VM takes down the way into everything else. That is an
acceptable trade for a homelab — the proxy is a convenience layer, and every
service stays reachable by `IP:port` when it is down — but it is a trade, and
it is the first thing to revisit if the gateway becomes load-bearing.

## Architecture

Everything runs as containers on `pfe`, which already has Docker installed by
its cloud-init and already runs `docker compose`.

```
  Browser (client VLAN, or WireGuard)
        │  https://plex.labxp.io
        │
        │  Pi-hole answers with pfe's address
        ↓
  ┌────────────────────────────────────────────────┐
  │  pfe  192.168.201.14  (VLAN 201, gw .1)        │
  │                                                │
  │   caddy  :80 :443    ← the only published ports│
  │     │                                          │
  │     ├── homepage:3000      (portal)            │
  │     ├── redlib:8080        (existing)          │
  │     │                                          │
  │     └── off-box upstreams, by IP:port ────────┐│
  └───────────────────────────────────────────────┼┘
                                                  │
        ┌─────────────┬───────────────┬───────────┘
        ↓             ↓               ↓
   Proxmox:8006   Plex:32400    lab VMs (VLAN 200)
   (VLAN mgmt)    (VLAN 10)     openclaw, cmd-and-ctrl…
```

Caddy is the only thing binding host ports. `redlib` loses its current
`8080:8080` publish and joins an internal `proxy` Docker network, where Caddy
reaches it by container name. Homepage never binds a host port at all.

Three containers in `docker-compose.yaml`:

| Container | Image | Notes |
|-----------|-------|-------|
| `caddy` | `ghcr.io/krakenhavoc/homelab/caddy-cloudflare` | Custom build — see below. Binds :80, :443. Persistent volume for the certificate store. |
| `homepage` | `ghcr.io/gethomepage/homepage` | Pinned to a release tag, not `latest`. |
| `redlib` | `quay.io/redlib/redlib` | Existing. Only change is dropping the host port publish. |

### The custom Caddy image

`caddy-dns/cloudflare` is not in the standard Caddy distribution — it has to be
compiled in with `xcaddy`. This repo already builds and publishes an image to
GHCR (`docker/get-win-url/` plus `.github/workflows/docker-get-win-url.yaml`),
so a `docker/caddy-cloudflare/` directory following the same pattern is the
natural home:

```dockerfile
FROM caddy:<version>-builder AS builder
RUN xcaddy build --with github.com/caddy-dns/cloudflare

FROM caddy:<version>
COPY --from=builder /usr/bin/caddy /usr/bin/caddy
```

Building it here rather than pulling a third-party prebuilt keeps the supply
chain to Caddy upstream plus this repo, and it is roughly ten lines.

### Homepage and the docker socket

Homepage's Docker widgets need access to the Docker socket. It should get that
through a read-only socket proxy (`tecnativa/docker-socket-proxy`) with only
`CONTAINERS=1`, never a direct `/var/run/docker.sock` bind mount. A direct
mount hands a container that renders a web page the ability to start a
privileged container on the host, which is root on `pfe` by another name.

### `HOMEPAGE_ALLOWED_HOSTS`

Homepage v1.0 made this environment variable mandatory for any access that is
not `localhost`. Behind a reverse proxy it must list the **browser-facing**
hostname (`labxp.io`), not the container name or the proxy's IP. Getting
it wrong does not fail loudly — it presents as a blank page or
`Host validation failed`, and it is the single most common way this
deployment will fail on first try. Do not set it to `*`.

## Why config does not live in cloud-init

This is the constraint that shapes everything else, and it is not optional.

The `pm-cloudinit-vm` module has **no `lifecycle { ignore_changes = [initialization] }`**,
and neither does the `frontends` deployment. Editing a cloud-init template
replaces `proxmox_virtual_environment_file` (`source_raw` forces replacement),
which makes its ID unknown at plan time, which propagates into
`user_data_file_id`, which **replaces the VM**. This is precisely the mechanism
that destroyed the production `cmd_and_ctrl` VM and its data disk on
2026-09-10; `cmd_and_ctrl` now carries an `ignore_changes` block for exactly
this reason, and `frontends` does not.

A gateway is a thing you tune constantly — a new upstream, a header tweak, a
portal link. If the Caddyfile lives in cloud-init, **every one of those edits
rebuilds the VM and discards the Let's Encrypt certificate store.** That is
not a theoretical cost: Let's Encrypt permits 5 duplicate certificates per
week, so a few afternoons of iteration ends in rate-limited failure with no
certificates and no obvious cause.

So the split is:

- **cloud-init does first-boot bootstrap only** — install Docker, create
  directories, write the env file, start the stack once. It is the same
  approach `cmd_and_ctrl` takes, where cloud-init writes a Caddyfile
  explicitly labelled `FIRST BOOT PLACEHOLDER ONLY`.
- **ongoing config is pulled from this repo** — `gateway-sync`, a systemd
  timer on `pfe`, fetches `gateway/` every minute, validates the incoming
  Caddyfile against the running Caddy, copies it to `/opt/gateway/live/` and
  runs `docker compose up -d`. Push to `main` and the gateway follows within
  the minute.

Pull rather than push, which was the original sketch. Pushing would have
meant a CD job SSHing from the runner into the apps VLAN, which needs a key
on the runner, an inbound path to `pfe`, and a reason for CI to hold
credentials for a host it otherwise never touches. The repository is public,
so pulling needs none of that: no key, no inbound path, nothing for CI to
hold. The cost is a minute of latency and a fetch that is a few hundred bytes
when nothing changed.

The validation step matters more than it looks. An invalid Caddyfile does not
degrade the gateway, it stops it — Caddy refuses to start and every internal
name goes dark at once. Checking the incoming file with the Caddy that is
already running turns that into a log line and a no-op.

Terraform keeps the VM and the one secret. `gateway/` keeps everything else.

## TLS without exposing anything

Caddy obtains genuine Let's Encrypt certificates using the **DNS-01**
challenge against the `labxp.io` zone. DNS-01 never requires an inbound
connection, so the lab stays entirely unreachable from the internet while
browsers still show a normal padlock with no warnings and no root CA to
install on every device.

Two details that will otherwise cost an evening:

1. **Per-host certificates, not a wildcard.** A `*.labxp.io` wildcard would be
   one certificate instead of ten, but its private key — sitting on the apps
   VM — would be able to impersonate `cmd.labxp.io`, which is a live public
   service. Individual certificates keep the blast radius of a compromised
   `pfe` to the internal names.

2. **Pin Caddy's resolvers to a public resolver** (`resolvers 1.1.1.1`) in the
   `tls` block. Caddy verifies that its `_acme-challenge` TXT record has
   propagated before asking Let's Encrypt to validate. If that check runs
   through Pi-hole, which is about to hold local overrides for these very
   names, propagation checks can fail or hang against a split-horizon view.

Sketch:

```caddyfile
(cloudflare_tls) {
    tls {
        dns cloudflare {env.CF_DNS_API_TOKEN}
        resolvers 1.1.1.1
    }
}

labxp.io {
    import cloudflare_tls
    reverse_proxy homepage:3000
}

redlib.labxp.io {
    import cloudflare_tls
    reverse_proxy redlib:8080
}

proxmox.labxp.io {
    import cloudflare_tls
    reverse_proxy https://<pve-ip>:8006 {
        transport http {
            tls_insecure_skip_verify   # Proxmox serves its own self-signed cert
        }
    }
}
```

### `pve.labxp.io` must be left alone

`pve.labxp.io` is the Proxmox API endpoint that the `bpg/proxmox` provider
talks to (`https://pve.labxp.io:8006`) from CI on the self-hosted runner. It is
tempting to put Proxmox behind the proxy under its existing name. Do not:
repointing that record sends every Terraform run in the repository through
Caddy, and a proxy hiccup becomes a CI outage across every deployment.

Use a **second** name — `proxmox.labxp.io` — for browser access, and leave
`pve.labxp.io` resolving directly to the node as it does today.

## DNS

Both Pi-holes get a local A record per gateway hostname, all pointing at
`pfe`'s address. Both, not one: a single entry means every lab name stops
resolving while that Pi-hole reboots.

These names are deliberately **not** created in public Cloudflare DNS. They
resolve only inside the network; from outside they are `NXDOMAIN`. DNS-01 is
unaffected, because that writes short-lived `_acme-challenge` TXT records via
the Cloudflare API rather than needing the A records to be public.

**Use plain host records, never a dnsmasq wildcard.** This is not a style
preference now that the portal is on the apex. A Pi-hole "Local DNS Record"
for `labxp.io` matches that exact name and nothing else. A dnsmasq
`address=/labxp.io/192.168.201.14` line matches the apex *and every subdomain
under it* — it would swallow `cmd.labxp.io` (a live public service),
`pve.labxp.io` (the endpoint every Terraform run in this repo uses) and
`cmd-dev.labxp.io` in one go, and the failure would look like the gateway
serving the wrong site rather than like a DNS entry.

The apex override has one accepted consequence even when done correctly:
anything published at `labxp.io` itself on the public internet is unreachable
from inside the lab, because both Pi-holes now answer that name with
192.168.201.14. Subdomains are untouched.

The records needed, all pointing at `192.168.201.14`, on **both** Pi-holes:

| Name | Serves |
|------|--------|
| `labxp.io` | the portal |
| `redlib.labxp.io` | RedLib |
| `plex.labxp.io` | Plex (192.168.10.10:32400) |
| `proxmox.labxp.io` | Proxmox web UI |
| `dns01.labxp.io` | Pi-hole 192.168.10.11 |
| `dns02.labxp.io` | Pi-hole 192.168.10.12 |

`dns01` and `dns02` pointing at the gateway rather than at the Pi-holes
themselves looks circular and is not: DNS queries reach a resolver by address,
never by name, so a Pi-hole answering its own web hostname with the gateway's
address does not affect its ability to resolve.

The record list should live in this repo as a plain file so it is reproducible
and reviewable, rather than existing only as clicks in two Pi-hole UIs.

## Firewall

Two directions, both manual in OPNsense, and the second deserves thought.

- **Inbound:** client VLAN(s) → `pfe:443` (and `:80`, which Caddy uses only to
  redirect to HTTPS).
- **Outbound:** `pfe` → every upstream it proxies — Proxmox `:8006`,
  Plex `:32400` on VLAN 10, the lab VMs on VLAN 200, and `:443` outbound to
  the internet for ACME and the Cloudflare API.
- **Outbound DNS:** `pfe` → `192.168.10.11` and `192.168.10.12` on `:53`,
  UDP **and** TCP. Easy to overlook because the Pi-holes are not proxied
  upstreams, they are the gateway's own resolvers — and `pfe` (VLAN 201)
  reaching them (VLAN 10) is an inter-VLAN flow like any other. Without it
  the host boots with resolvers it cannot reach, which looks like a hung
  first boot rather than a firewall problem.

That outbound set is the real cost of this design. The documented posture is
default-deny between VLANs; this deliberately drills a hole from the apps VLAN
into the management, server and lab VLANs, which makes `pfe` the most
valuable host on the network to compromise. It is the unavoidable price of a
central reverse proxy, but it should be **per-destination-and-port rules, never
"VLAN 201 → any"**, and `pfe` should be treated as a tier-0 host from here on.

## Secrets

| Secret | Scope | Used by |
|--------|-------|---------|
| `CF_DNS_API_TOKEN` | existing repo `cloudflare_api_token` — **decided** | Caddy, for DNS-01 |
| Proxmox API token | read-only | Homepage widget |
| Plex token | — | Homepage widget |
| Pi-hole app password | — | Homepage widget |

**Decided:** reuse the existing `cloudflare_api_token` rather than minting a
dedicated DNS-01 token. It already holds `Zone:DNS:Edit` on `labxp.io`, which
is what the challenge needs.

Two caveats recorded rather than solved:

- That token *also* carries `Cloudflare One Connector: cloudflared: Edit`.
  Filesystem access on `pfe` therefore grants tunnel create/reconfigure on the
  whole account, not just DNS writes — a wider blast radius than DNS-01 needs.
  Swapping to a scoped token later is a one-line change to the env file.
- **Verify it carries `Zone:Zone:Read`.** `caddy-dns/cloudflare` resolves the
  zone ID with `GET /zones?name=labxp.io`, which needs `Zone:Read` on top of
  `DNS:Edit`. Cloudflare's "Edit zone DNS" template includes it, so this is
  probably already true — but if it is not, the failure arrives at certificate
  issuance as an empty zone lookup rather than as a permission error, which is
  a confusing hour.

The token is a `lab` deployment variable today, so it also needs plumbing into
`frontends` as a new variable plus a GitHub environment secret.

Cloudflare scopes tokens per *zone*, not per *record*, so any DNS-01 token
here can edit `cmd.labxp.io` as well. That is inherent to DNS-01 on a shared
zone; a delegated `_acme-challenge` CNAME into a throwaway zone would close it
properly and is not worth the complexity.

All of these follow the existing path: GitHub environment secret → `TF_VAR_*`
→ `templatefile` → env file on the host, exactly as the `cmd_and_ctrl` tokens
do today.

## Phases

Each phase is independently reviewable and leaves the lab working.

**Phase 0 — Pin `pfe`'s address.** *Unblocked; lands with Phase 3.*
Every DNS name resolves here, so the address cannot be a DHCP lease.
`192.168.201.14/24`, gateway `192.168.201.1`, resolvers `192.168.10.11` and
`192.168.10.12`.

The release blocker is gone: PR #65 merged and `v0.3.0` is tagged on `main`,
so `pm-cloudinit-vm` declares `vm_ipv4_address` and the `frontends` ref can
be bumped.

It is deliberately **not** a standalone change any more. Applying a static
address rewrites the cloud-init drive, and cloud-init is first-boot-only, so
the provider replaces the guest. Installing the gateway stack rewrites the
same drive and forces the same replacement. Doing them separately rebuilds
`pfe` twice for one outcome, so Phase 0 and Phase 3 ship in one PR.

Do it before Caddy holds any certificates. Today `pfe` runs only stateless
RedLib and a rebuild costs nothing; once the certificate store is on the box,
the same change spends Let's Encrypt rate-limit budget (5 duplicate certs per
week) and can leave the gateway with nothing valid to serve.

The alternative — a DHCP reservation on OPNsense keyed to `pfe`'s current MAC
— avoids a rebuild but does not survive one, because a rebuild draws a new
MAC. Given the box is disposable right now, declaring it is cheaper now than
it will ever be again.

**Phase 1 — Custom Caddy image. ✅ Done.**
`docker/caddy-cloudflare/Dockerfile` plus `.github/workflows/docker-caddy-cloudflare.yaml`,
mirroring the existing `docker-get-win-url.yaml` pattern. Built locally against
Caddy v2.11.4 and confirmed: `caddy list-modules` lists
`dns.providers.cloudflare`.

The workflow asserts that module is present on every build rather than
trusting the build to have included it. A build that silently drops the plugin
still succeeds, still pushes and still starts — it fails hours later at
certificate issuance, on the host, with `unknown DNS provider`.

**Phase 2 — Config delivery. ✅ Done.** `gateway/` plus `gateway-sync` and
its systemd timer. Shellchecked; the compose file passes `docker compose
config`.

**Phase 3 — Caddy and TLS, one upstream.** Stand up Caddy in front of RedLib
only, at `redlib.labxp.io`. This is the phase that proves DNS-01, the token,
the Pi-hole records and the firewall rules all work, against a service whose
failure costs nothing.

**Phase 4 — Homepage.** The portal itself at the `labxp.io` apex, with links to
every service and widgets for Proxmox, Plex and Pi-hole.

**Phase 5 — Remaining upstreams.** Proxmox, Plex, the OpenClaw hosts,
`cmd-and-ctrl`, and whatever else earns a name. One Caddyfile block, one
Pi-hole record and one firewall rule each.

**Phase 6 — Documentation.** Fold the result into `docs/service-deployment.md`
and `docs/network-setup.md`, and record the DNS record list.

## Facts required before implementation

Every item below is a fact about the physical network that cannot be derived
from inside this repository, and guessing any of them causes a failure that
does not point back at this file. An IP conflict in particular presents as
intermittent, unattributable packet loss on *two* hosts.

1. ~~**`pfe` static address**~~ — **`192.168.201.14/24`**, supplied and
   confirmed outside the VLAN 201 DHCP pool.
2. ~~**VLAN 201 gateway**~~ — **`192.168.201.1`**, supplied.
3. ~~**Both Pi-hole addresses**~~ — **`192.168.10.11`** and
   **`192.168.10.12`**, supplied.
4. **ACME contact email** for Let's Encrypt.
5. ~~**A new Cloudflare API token**~~ — decided: reuse the repo's existing
   `cloudflare_api_token`. See [Secrets](#secrets) for the two caveats.
6. **The upstream list** — which services get a name, and each one's address
   and port. Candidates: Proxmox, Plex (prd and dev), RedLib, OpenClaw,
   OpenClaw-2, `cmd-and-ctrl` (prod and dev preview), the Windows 11 VM,
   Pi-hole itself.
7. **Which client VLAN(s)** you browse from, for the inbound firewall rule.
8. ~~**Confirmation of the portal hostname**~~ — the `labxp.io` apex.

Both Pi-holes sit on VLAN 10 while `pfe` is on VLAN 201, so the outbound
firewall rule set below must include `pfe → 192.168.10.11/12:53` (UDP and
TCP). This is easy to miss because it is not one of the proxied upstreams —
and if it is missed, the symptom is a first boot that hangs rather than a
DNS error, exactly as the validation message warns.

## Risks and trade-offs

- **Single point of failure.** `pfe` going down takes the portal, the proxy
  and RedLib with it. Every service remains reachable at `IP:port`, so this
  degrades access rather than severing it — but the whole value of the
  gateway is not having to remember those.
- **`pfe` becomes tier-0.** The outbound firewall rules make it the best
  pivot point on the network. Per-port rules and prompt patching, not
  "VLAN 201 → any".
- **Cloudflare token blast radius.** Zone-scoped, not record-scoped. Inherent
  to DNS-01; documented above rather than solved.
- **Split-horizon divergence.** Names resolving differently inside and outside
  is a well-known source of confusing bugs. Keeping the record list in the
  repo is the mitigation.
- **Homepage upgrades.** Pin the image tag. `latest` on a portal that renders
  YAML from this repo means an upstream schema change can blank the page at an
  arbitrary time with no change on your side.

## Rejected alternatives

**Cloudflare Tunnel for everything.** Would reuse the proven `cmd_and_ctrl`
pattern and need no firewall changes at all. Rejected because it routes
internal lab traffic out to Cloudflare and back for a LAN-only use case, and
puts an Access login in front of every internal app.

**Nested names (`plex.lab.labxp.io`).** Cleaner namespace, but Cloudflare
Universal SSL covers only single-label subdomains — a nested name that is ever
put behind Cloudflare needs paid Advanced Certificate Manager. Flat names keep
that door open.

**A separate internal zone (`*.lab.internal`).** No Cloudflare involvement,
but `.internal` cannot get public ACME certificates, so it means running an
internal CA and installing its root on every browsing device — which is the
specific pain this design exists to avoid.

**A dedicated gateway VM.** Architecturally cleaner and decouples the portal
from RedLib's fate. Rejected for now on cost/benefit; revisit if the gateway
becomes load-bearing. Nothing in this plan forecloses it — the `config/`
directory and the custom image move to a new host unchanged.

**Homarr instead of Homepage.** Nicer to edit, but its state lives in a
database on the VM, so the layout drifts out of Git and is not reproducible
from a rebuild. That is the opposite of how everything else here is managed.

---

Related: [Service Deployment](service-deployment.md) ·
[Network Setup](network-setup.md) · [Security Guidelines](security.md)
