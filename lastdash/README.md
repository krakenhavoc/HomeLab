# LastDash

This directory contains runtime configuration for [LastDash](https://github.com/krakenhavoc/lastdash). The application runs on a dedicated VM and is available only through the private gateway to trusted LAN and VPN clients.

| Piece | Owner |
| --- | --- |
| VM and first boot | `terraform/deployments/lastdash` through `deploy.yaml` |
| Web, API, Postgres, and Redis | `lastdash/docker-compose.yaml` |
| Reconcile loop | `lastdash/bootstrap/` |
| TLS and private routing | `gateway/caddy/Caddyfile` |
| Portal entry | `gateway/homepage/services.yaml` |
| Application images | LastDash application repository |

## How updates work

The host periodically fetches `main`, validates the Compose configuration, pulls the selected application images, and reconciles the stack.

Infrastructure and application delivery are intentionally separate:

- Terraform creates the VM and supplies first-boot inputs.
- The sync service delivers routine Compose changes without rebuilding the VM.
- The application repository builds the web and API images.
- A pinned image tag can hold a known version during investigation or rollback.

The VM protects its initialization settings because it owns a database. Changing a cloud-init value does not update an existing host; runtime credentials must be rotated through the host's secret-management path.

## Deployment checklist

1. Confirm the production GitHub environment can resolve the required Bitwarden items.
2. Confirm the HCP Terraform workspace exists in local execution mode.
3. Reserve a stable address without documenting it in the public repository.
4. Add the private gateway route, explicit internal DNS record, and narrow firewall path.
5. Verify the application remains inaccessible from public networks.
6. Review the Terraform plan for replacement before merging.
7. Confirm cloud-init, the sync service, database health, and the gateway route after deployment.

## Data migration

Production may be initialized from an existing database dump. Preserve the application encryption key when migrating encrypted integration tokens; without the original key, copied ciphertext cannot be recovered.

A safe migration follows this order:

1. Quiesce application writers.
2. Create a custom-format Postgres dump.
3. Transfer it over the trusted management path.
4. Stop the API and web containers.
5. Restore into the intended database with ownership normalized.
6. Restart the application and verify integrations before reopening access.
7. Remove temporary dumps from both systems.

Do not put database dumps, environment files, tokens, internal addresses, or credential identifiers in Git or workflow logs.

## Access boundary

LastDash does not yet provide a production-grade authentication boundary. Its API trusts identity supplied by the client integration, so network placement is part of the security model.

Keep the service behind the private gateway and limit it to trusted LAN and VPN clients. Do not create public DNS or a public tunnel until the application has independent authentication and authorization.

Internal names, addresses, network identifiers, and secret names are intentionally omitted from this public guide.
