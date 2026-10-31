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
| ReazonSpeech for reading answers | `wkjp/asr/` (built on the VM) |
| Reconcile loop | `wkjp/bootstrap/` |
| Pronunciation check report | `wkjp/tools/rec-report.py` |
| TLS and private routing | `gateway/caddy/Caddyfile` |
| Portal entry | `gateway/homepage/services.yaml` |

## Notes

- No secrets, and no server-side state apart from pronunciation check
  recordings (below). The WaniKani token and study stats live in the
  browser's localStorage, per origin, and API calls go straight from the
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
- Spoken **readings** go to ReazonSpeech k2 v2 first. It's a Japanese-only
  int8 transducer, built from `wkjp/asr/` and run on this VM's CPU behind
  `/asr/transcribe` (raw clip in, `{"text"}` out), at about 0.1 s a word.
  - If ReazonSpeech hears an accepted reading, that's the answer.
    Otherwise Whisper gets its turn as before. When ReazonSpeech has an
    answer, Whisper isn't waited on past 15 s.
  - If Whisper hears nothing or a stock phrase, ReazonSpeech's text is
    judged instead.
  - Meanings and Talk stay on Whisper; ReazonSpeech is Japanese only.
  - The pronunciation check runs both on every take and on the VOICEVOX
    control, and shows each one's result.
  - **Why:** on 23 real takes from the user (G733 headset, Brave), Whisper
    large-v3-turbo heard 9 as meant, kotoba-whisper v2 11, ReazonSpeech 11,
    and "either Whisper or ReazonSpeech" 15. The same Whisper weights scored
    the same on base-station's CPU as on KBU, so KBU's hardware wasn't the
    limit.
  - **Failure handling:** nginx resolves `asr` per request, so a missing or
    crashing container only turns `/asr/` into a 502, and the app falls
    back to Whisper alone. compose builds the image (`pull_policy: build`);
    the first build downloads the model (~160 MB, pinned revision).
  - **CPU type:** the VM's `x86-64-v2-AES` CPU type hides AVX/AVX2, which
    ONNX Runtime would use. An AVX2 type (`x86-64-v3`) would speed it up,
    once the Proxmox host is confirmed to support it.
- KBU's RX 6800M runs hot, and `kbu-gpu-guard` there freezes `whisper-server`
  near 100 °C, sometimes for a couple of minutes. Requests hang meanwhile,
  then nginx answers 504, or 502 as Whisper resumes. Reviews, the
  pronunciation check and Talk hold the clip and send it again (`sttPost`):
  one request at a time, 8 s apart, for up to 3 minutes, with a "Whisper on
  KBU isn't answering" status. The Reviews "next / again" listener doesn't
  retry.
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
- When Whisper can't make out the speech it fills in a stock phrase from
  its subtitle training data, such as お待ちしております for a mumbled ぶんか
  or "Thank you." for a cough. Reviews treat those as "couldn't make that
  out, say it again" rather than as an answer, unless the phrase really is
  the item's answer (`sttStock`, `rvIsAnswer`).
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
- The Speak tab's pronunciation check plays words one at a time:
  - **Word order:** words you type first, then readings your reviews
    misheard (`wkl_voice_misses`, the last 30), then random learned
    vocabulary. With nothing loaded, it uses one-sound pairs
    (病院/美容院, 切手/来て).
  - **Each take:** goes through the Reviews reading call with
    `response_format=verbose_json`. That gives whisper.cpp's language
    probabilities even when forced to Japanese, shown as "% Japanese".
  - **The control:** VOICEVOX says the word, with half a second of silence
    each side because Whisper clips a bare word, and goes through the same
    call. When Whisper misses VOICEVOX too, the page says the word is hard
    for Whisper.
  - **Mic:** each take shows how far the voice stands above the
    background, measured from the clip. It also flags 0.3 s or more of
    exact digital silence, which means a gate in the browser or headset
    holds the mic shut until you speak and can clip the first consonant.
    A G733 headset through Brave measured 21–34 dB with the gate on every
    take. VOICEVOX measures about 66 dB.
  - **Stock phrases** are labelled as such, not as what you said.
  - **"Browser noise suppression":** switches the browser's
    noise/echo/gain processing for the check and Reviews alike.
- Check takes are PUT to `/rec/<session>/NN-T.webm`, with a `session.json`
  holding what was heard. nginx stores them in `/opt/wkjp/rec` with WebDAV
  PUT:
  - It takes nothing else: a name pattern, 2 MB at most, no DELETE.
  - `GET /rec/` lists sessions as JSON.
  - wkjp-sync creates the directory for nginx's uid 101 and deletes
    sessions older than 90 days.
  - The directory sits outside the synced tree, so the VM is still
    disposable: losing it only loses recordings.
- The app's mic detector (`micUtterance`) decides when an answer starts and
  ends, before anything is sent:
  - **Start:** speech must stand about 15 dB over the room and never under
    -48 dBFS (`MIC_MIN`, `MIC_OVER`), for 150 ms.
  - **Room level:** the quietest level of the last 3 s, so it doesn't creep
    up while someone talks.
  - **End:** 0.8 s at 15 dB under the answer's loudest point (`MIC_TAIL`),
    so hiss a headset lets through after its gate opens can't hold the mic
    open.
  - **Why:** the old fixed -36.5 dB threshold missed a G733 headset with
    browser processing off. Voices peaked at -34 to -18 dB, but some only
    stayed over the line for 50–100 ms. The G733 gates its mic itself:
    digital silence until speech, with or without browser processing.
- Reviews records what the app's own mic detector saw every time it
  listened: peak level against the threshold, speech time and background
  floor, as `sent`, `silent` or `cancelled`.
  - With "save my spoken answers" on (the default), each answer clip goes to
    `/rec/<session>/NNNN-1.webm`. A `session.json` with `kind: "reviews"`
    holds what Whisper and ReazonSpeech heard and the verdict.
  - A listen where the voice got within half of the threshold, but never
    crossed it, says so instead of quietly starting over.
  - The level meters mark the threshold at 40% and turn green above it.
- `wkjp/tools/rec-report.py [session]` (newest by default) runs a session's
  takes through five Whisper settings: the app's, no prompt, the answer as
  the prompt, auto language, and beam search. It also runs three VOICEVOX
  voices, then sorts each word into fine, whisper, settings, close or you
  (see the script header). Run it from the LAN.
- Changes to anything here go live within ~5 minutes of merging, via
  `wkjp-sync`. nginx config changes trigger a reload.
- Stateless, so the VM can be replaced freely.
