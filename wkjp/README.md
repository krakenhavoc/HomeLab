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
- Talk's prompt lists the learner's newest ~800 learned words, plus, when
  Settings → "New words in Talk" is above 0% (default 15%), the nearest ~150
  unlearned WaniKani words to draw new words from. The model treats the
  percentage as a rough target. "Send automatically when I stop the mic" sends
  the transcription as soon as Whisper returns it.
- The Talk mic records in the browser and posts the clip to `/stt/`, proxied
  to whisper.cpp (large-v3-turbo, Vulkan on the RX 6800M) on KBU,
  192.168.1.201:8080 (`~/.config/containers/systemd/whisper-vk.container`).
  That Quadlet runs with Silero VAD (`--vad --vad-model
  /models/ggml-silero-v6.2.0.bin --vad-threshold 0.35 --vad-speech-pad-ms
  200`), so silence and loud noise come back empty instead of as invented
  subtitle lines such as ご視聴ありがとうございました. The default 0.5 threshold
  clipped speech in moderate noise. The app also drops those stock phrases and
  prompt echoes, and shows "didn't catch that" without auto-sending.
  Settings → "Mic language" switches Whisper from forced Japanese to
  auto-detect for English or mixed speech.
- The Reviews tab does the WaniKani reviews that are due, WaniKani-style
  (meaning and reading, ~10 items in play, misses come back), answered by
  voice or typing. Meaning answers go to the same Whisper as English,
  reading answers as Japanese with a `ひらがな。` prompt, which gets kana
  instead of kanji for most single words. Checking allows for Whisper's
  habits: vowel length is ignored (がっこう heard as がっこ), digits map to
  readings (さん comes back as `3`), and a word written in kanji is resolved
  through the review's own subjects, the cached vocab, then VOICEVOX's
  `audio_query` reading. When Whisper writes the kanji being asked about,
  the clip is transcribed again with that kanji's readings as the prompt;
  only if it's still the kanji does the app ask "did you say …?". A near
  miss (dakuten, small kana) asks again; a wrong answer only counts after
  "next", so "again" covers a mishearing.
- A spoken reading has to be Japanese, but forced-Japanese Whisper still
  writes English or digits now and then: `10` for てん, because it heard
  "ten". The app judges the sound instead. Romaji becomes kana, and a
  number its English sound (10 → てん), so 天 passes and 変 (へん) doesn't.
  If that misses, the clip is transcribed again with the item's readings as
  the prompt. That pass can only turn a miss into a pass, and only its first
  part counts, because Whisper sometimes copies the prompt's list. If the
  answer still isn't Japanese, the app asks once more before marking it
  wrong. The server ignores `suppress_regex`, so Latin tokens can't be
  banned outright.
- Meaning and reading questions look different on purpose: meaning is a
  light paper bar and answer box with an `A` badge, reading is dark ink with
  `あ`, following WaniKani's light/dark convention.
- Each tab carries its Japanese word (練習, 復習, 話す, 会話, 統計, 設定),
  beside the English on wide screens and above it below 700px, with the
  reading in the tooltip.
- After a wrong answer the item's reading is spoken (setting, plus 🔊 / `p`).
  The mic stays off while it plays, so it doesn't hear itself.
- "Let me check the results before they're sent" (on by default) holds
  finished items in localStorage (`wkl_rv_hold`) instead of sending them.
  The done card lists them: mark a miss correct if Whisper misheard, untick
  one to leave it due, then send. Held items are left out of new sessions.
- Finished items are POSTed to `/v2/reviews`. That needs a token with
  `reviews:create`; the default read-only one gets a 403, and the results
  wait in localStorage (`wkl_rv_outbox`) until a token that can write is
  pasted on the Reviews tab. "Send results to WaniKani" off makes it
  practice only.
- Changes to anything here go live within ~5 minutes of merging, via
  `wkjp-sync`. nginx config changes trigger a reload.
- Stateless, so the VM can be replaced freely.
