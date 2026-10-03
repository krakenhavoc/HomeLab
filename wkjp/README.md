# wkjp

WaniKani listening practice: a single-page app that pulls vocabulary with the
user's WaniKani API token and speaks it with VOICEVOX. Runs on its own VM and
is reachable only through the private gateway.

| Piece | Owner |
| --- | --- |
| VM and first boot | `terraform/deployments/wkjp` through `deploy.yaml` |
| App and VOICEVOX | `wkjp/docker-compose.yaml` |
| The app itself | `wkjp/site/index.html` |
| `/vv/` proxy to VOICEVOX | `wkjp/nginx/default.conf` |
| Reconcile loop | `wkjp/bootstrap/` |
| TLS and private routing | `gateway/caddy/Caddyfile` |
| Portal entry | `gateway/homepage/services.yaml` |

## Notes

- No server-side state or secrets. The WaniKani token and study stats live in
  the browser's localStorage, per origin, and API calls go straight from the
  browser to WaniKani.
- VOICEVOX is not published. nginx proxies an allowlist of endpoints under
  `/vv/` and drops the `Origin` header, which the engine would otherwise 403.
- The Talk tab chats through `/llm/`, which nginx proxies to Ollama on
  base-station (192.168.1.18:11434, `~/llm/local-compose.yaml` there). Only
  `/api/chat` and `/api/tags` pass. When base-station is off, Talk shows an
  error and the rest of the app is unaffected.
- The Talk mic records in the browser and posts the clip to `/stt/`, proxied
  to speaches (Whisper large-v3-turbo, CPU) on base-station port 8001.
- Changes to anything here go live within ~5 minutes of merging, via
  `wkjp-sync`. nginx config changes trigger a reload.
- Stateless, so the VM can be replaced freely.
