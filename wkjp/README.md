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
- `/vv/` goes to VOICEVOX on KBU (192.168.1.201:50021, Quadlet `voicevox`)
  first: ~0.4 s per sentence there vs ~10 s on this VM, which is too slow for
  Talk's read-aloud. The local engine is the backup when KBU is unreachable.
- The Talk tab chats through `/llm/`, which nginx proxies to Ollama on
  base-station (192.168.1.18:11434, `~/llm/local-compose.yaml` there). Only
  `/api/chat` and `/api/tags` pass. When base-station is off, Talk shows an
  error and the rest of the app is unaffected.
- Each Talk reply gets a follow-up `/api/chat` call that splits it into words
  with reading and meaning, for the hover/tap glosses. Kanji words not in the
  learned set get a dotted underline.
- The Talk mic records in the browser and posts the clip to `/stt/`, proxied
  to whisper.cpp (large-v3-turbo, Vulkan on the RX 6800M) on KBU,
  192.168.1.201:8080 (`~/.config/containers/systemd/whisper-vk.container`).
- Changes to anything here go live within ~5 minutes of merging, via
  `wkjp-sync`. nginx config changes trigger a reload.
- Stateless, so the VM can be replaced freely.
