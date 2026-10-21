# netcrawl

The browser build of NetCrawl, a Godot game, served from its own VM and reachable only through the private gateway. Design and rollout: [docs/netcrawl-web.md](../docs/netcrawl-web.md).

| Piece | Owner |
| --- | --- |
| VM and first boot | `terraform/deployments/netcrawl` through `deploy.yaml` |
| nginx | `netcrawl/docker-compose.yaml`, `netcrawl/nginx/` |
| Reconcile loop and release pruning | `netcrawl/bootstrap/` |
| CI deploy key (public half) | `netcrawl/deploy/authorized_keys` |
| The releases themselves | NetCrawl repository CI, pushed to `/srv/netcrawl/www` |
| TLS and private routing | `gateway/caddy/Caddyfile` |
| Portal entry | `gateway/homepage/services.yaml` |

## Notes

- Static files only. Saves live in each player's browser (IndexedDB, per origin), so the VM is stateless and can be replaced freely. A rebuild loses old releases, and the next CI run writes a new one.
- CI uploads `r/<sha>/` first and then replaces `index.html`, which redirects to it. `r/**` is cached forever, and `index.html` is never cached.
- Upload with `--chmod=D755,F644`. nginx runs as a different user from `deploy`, and it can only serve what it can read.
- `netcrawl-sync` keeps the newest five releases plus whichever one `index.html` points at. If it can't read the pointer, it deletes nothing.
- The deploy key can only write under `/srv/netcrawl/www` (`rrsync -wo -no-del`). `netcrawl-sync` refuses to install an `authorized_keys` file that has any line without that forced command.
- Changes here go live within about 5 minutes of merging. nginx reloads only if `nginx -t` passes.

## Renaming

"netcrawl" is a working name, and the game is being renamed. A rename touches:

- `terraform/deployments/netcrawl/` (directory, tfvars `name_prefix`, backend tag) and its `tfc` workspace entry. Renaming the workspace means moving state, so plan it as a migration.
- `netcrawl/` (directory, paths in the sync script, units, compose and cloud-init template).
- The gateway site name, the portal card, both Pi-hole records and the TLS name. The wildcard certificate already covers any single-label name. Done: the site is `niju-dev.labxp.io`, and `netcrawl-dev` redirects to it until its records are dropped.
- The NetCrawl repository's deploy workflow (host, path, known_hosts).

The VM is stateless, so the cheapest rename is to stand up the new name beside this one, point CI at it, and then remove this one.
