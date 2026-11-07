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
| Emoji for item pictures | `wkjp/tools/build-emoji.py` → `wkjp/site/emoji.json` |
| Anki words as known words | `wkjp/tools/anki-sync.py` + `wkjp/tools/systemd/` (on base-station) |
| TLS and private routing | `gateway/caddy/Caddyfile` |
| Portal entry | `gateway/homepage/services.yaml` |

## Notes

- One secret, the Anthropic API key for Talk, kept on the VM and never sent
  to the browser (below). Server-side state is that, the pronunciation
  check recordings and picture choices. The WaniKani token and study stats
  live in the browser's localStorage, per origin, and API calls go straight
  from the browser to WaniKani.
- VOICEVOX is not published. nginx proxies an allowlist of endpoints under
  `/vv/` and drops the `Origin` header, which the engine would otherwise 403.
- Speech runs on base-station (192.168.1.18, `~/llm/local-compose.yaml`
  there) since 2026-11-07, because KBU's GPU kept overheating:
  - `/vv/` goes to VOICEVOX on base-station's CPU (port 50121, ~0.3 s a
    sentence) first. This VM's own engine (~10 s, too slow for Talk's
    read-aloud) is the backup.
  - `/stt/` goes to whisper.cpp on base-station's RTX 5070 Ti (port 8080,
    ~0.1 s a clip) first, with KBU's whisper.cpp as the backup.
  - nginx skips a server that doesn't connect for 30 s, and every response
    carries `X-Served-By` with the address that answered.
  - The VM is on another VLAN, so base-station needs the route
    `192.168.0.0/16 via 192.168.1.1` in its `Hibiscus` NetworkManager profile
    while ProtonVPN is up; without it base-station's replies go into the
    tunnel, nginx can't connect, and everything falls back.
  - Inter-VLAN flows (allowed on the router, which denies by default; not
    in Git): from the wkjp VM 192.168.201.20 to base-station 192.168.1.18
    TCP 11434 (Ollama), 8080 (Whisper) and 50121 (VOICEVOX), and to KBU
    192.168.1.201 TCP 8080 (the Whisper backup). base-station runs no host
    firewall (ufw is installed but disabled).
- The Talk tab chats with Claude by default (Settings → "Talk with"), through
  `/claude/v1/messages`. nginx forwards only that POST to
  `api.anthropic.com` (TLS verified) and adds the API key itself, so the
  browser never has it.
  - **Models:** Sonnet 5.5 by default; Opus 5.5 or Haiku 5.5 from Settings.
    Each reply is labelled with the model that wrote it. The hover glosses
    always use Haiku 5.5.
  - **Requests:** structured outputs (the same JSON schemas Ollama gets, all
    objects closed), effort `low` for replies and glosses and `medium` for
    the sentence check, and two cache points: one on the system prompt (the
    known-words list), so a new chat or dictionary word reuses it, and
    top-level `cache_control`, so the chat so far is read from cache too.
    Sonnet and Opus calls
    opt into server-side fallback (`fallbacks: "default"`).
  - **Fallback:** if Claude can't answer (no key, an error, a refusal),
    Ollama does, and the reply's label says why.
  - **The key:** `/opt/wkjp/secrets/claude.conf` on the VM, root-only, one
    line `set $claude_key "sk-ant-...";`. Without it `/claude/` answers 503.
    Use a key from its own Console workspace with a monthly spend limit:
    the site is LAN-only, but anyone who can reach it can spend from it.
    To install or change it, run this in your own terminal (not through
    Claude Code, so the key stays out of any transcript):

    ```sh
    read -rsp 'Anthropic API key: ' K; echo
    printf 'set $claude_key "%s";\n' "$K" | ssh <you>@192.168.201.20 \
      'sudo sh -c "umask 077; mkdir -p /opt/wkjp/secrets; cat > /opt/wkjp/secrets/claude.conf" &&
       cd /opt/wkjp/live && sudo docker compose exec -T app nginx -t &&
       sudo docker compose exec -T app nginx -s reload'
    unset K
    ```
- Ollama is the alternative and the fallback: `/llm/` proxies to Ollama on
  base-station (192.168.1.18:11434, `~/llm/local-compose.yaml` there). Only
  `/api/chat` and `/api/tags` pass. When both are unavailable, Talk shows
  both reasons and the rest of the app is unaffected.
- Each Talk reply gets a follow-up call that splits it into words with
  reading and meaning, for the hover/tap glosses. Kanji words not in the
  learned set get a dotted underline.
- Talk replies stream: the reply call to Claude asks for `stream: true`, and
  nginx passes the server-sent events straight through (`proxy_buffering off`
  on `/claude/`). The app reads the `reply` field out of the JSON as it's
  written (`jsonFieldPrefix`), shows it in the bubble, and hands each finished
  sentence to VOICEVOX at once (`talkSpeaker`), so speech starts after the
  first sentence rather than after the whole reply. The sentence check and
  glosses don't stream. An Ollama reply comes whole and is read the old way.
- **Live mode** (🗣 Live) is hands-free conversation:
  - It listens with the Reviews mic detector (room-relative threshold, level
    meter), ends the turn after a 0.9 s pause (20 s at most), transcribes it,
    sends it, reads the streamed reply aloud, then listens again.
  - The mic is off while the reply plays, so it doesn't hear itself.
  - Space while it speaks interrupts and listens; space while you talk ends
    your turn now; Esc, the button or leaving the tab stops it.
  - It reads replies aloud whatever "read aloud" says; that box is for
    typed messages.
- Words started in Anki count as known too:
  - **Sync:** `wkjp/tools/anki-sync.py` runs on base-station (Flatpak Anki)
    every 15 minutes from a user timer. It reads the collection without
    touching it (SQLite's backup API, or a copy of the files while Anki holds
    its exclusive lock), takes the notes in "Kaishi 1.5k" with a card past
    "new", and PUTs their Word, Word Reading and Word Meaning to
    `/anki/known.json` (`/opt/wkjp/anki` on the VM) when the list changed.
  - **Install** (on base-station, from a checkout):
    `install -Dm755 wkjp/tools/anki-sync.py ~/.local/bin/wkjp-anki-sync`,
    `install -Dm644 -t ~/.config/systemd/user wkjp/tools/systemd/*`, then
    `systemctl --user daemon-reload && systemctl --user enable --now
    wkjp-anki-sync.timer`. `wkjp-anki-sync --dry-run` shows what it found.
  - **In the app:** `knownWords()` is the WaniKani learned words (newest
    level first) followed by the Anki ones WaniKani doesn't have. Talk's
    prompt (up to 1,500), its gloss underlines, and the dictionary's prompt
    (up to 3,000) and known-word check all use it. The listening Practice
    quiz and Reviews stay WaniKani-only. Settings → Vocabulary says how many
    came from Anki and when.
- Talk's prompt lists up to 1,500 known words (above), plus, when
  Settings → "New words in Talk" is above 0% (default 15%), the nearest ~150
  unlearned WaniKani words to draw new words from. The model treats the
  percentage as a rough target. "Send automatically when I stop the mic" sends
  the transcription as soon as Whisper returns it.
- Settings → "Grammar focus" (off, JLPT N5, N4 or N3) and "Grammar I'm
  working on" (a list such as `〜たい、〜てから`, e.g. from Bunpro) steer Talk:
  - Replies stay at that level and work a listed point into most replies,
    sometimes asking a question that invites the learner to use one. A
    `grammar` field in the reply schema names the point used, shown as
    `文法: 〜たい` under the reply.
  - The sentence check is told the focus: it names the grammar point behind
    a mistake, and says so when a listed point was used correctly.
  - Off (the default) keeps the old "keep grammar simple" prompt, and no
    `文法` tag shows.
- The Talk mic records in the browser and posts the clip to `/stt/`, proxied
  to whisper.cpp large-v3-turbo: on base-station, the 8-bit model (~1.3 GiB
  of VRAM, counted in Ollama's `OLLAMA_GPU_OVERHEAD` so the desktop keeps its
  headroom) in `ghcr.io/ggml-org/whisper.cpp:main-cuda`; on KBU, the Vulkan
  build (`~/.config/containers/systemd/whisper-vk.container`). Both run with
  `--inference-path /v1/audio/transcriptions --convert` and Silero VAD
  (`--vad --vad-model /models/ggml-silero-v6.2.0.bin --vad-threshold 0.35
  --vad-speech-pad-ms 200`), so silence and loud noise come back empty
  instead of as invented subtitle lines such as ご視聴ありがとうございました.
  The CUDA image has kernels up to sm_90; the driver compiles them for the
  5070 Ti's sm_120 on first use (~27 s), cached in
  `~/llm/whisper-cpp/cuda-cache` so a recreated container doesn't pay again. The default 0.5 threshold
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
  - **Paused Whisper:** if ReazonSpeech has an answer, Whisper gets 6 s,
    with "Checking with Whisper…" shown after 2 s. After that, the
    answer is judged on ReazonSpeech alone, and a miss says so.
  - **Second listens** (dropped r, English slip, own kanji) also give up
    after 6 s instead of retrying.
  - **No silent drops:** while an answer is being checked, the mic button,
    space and Enter say "Still checking your last answer…" instead of
    starting a new listen that would throw it away. On 2026-11-01 KBU's
    guard froze Whisper for 2 minutes mid-session. Readings went to "…" for
    15 s, and a press of space discarded them without a word.
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
  - **CPU type:** the VM runs with CPU type `host` (since 2026-11-04), so
    ONNX Runtime gets AVX2/FMA; `x86-64-v2-AES` hid them.
- Whisper can still be away: base-station off, or, on the KBU backup,
  `kbu-gpu-guard` freezing `whisper-server` near 100 °C for up to a couple of
  minutes (KBU's RX 6800M runs hot; that's why it's only the backup now).
  Requests hang meanwhile, then nginx answers 504, or 502 as Whisper
  resumes. Reviews, the pronunciation check and Talk hold the clip and send
  it again (`sttPost`): one request at a time, 8 s apart, for up to 3
  minutes, with a "Whisper isn't answering" status. The Reviews "next /
  again" listener doesn't retry.
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
- Each tab carries its Japanese word (練習, 学習, 復習, 話す, 会話, 辞書, 統計,
  設定) above the English, with the reading in the tooltip. Eight tabs don't
  fit side by side, so the stack is used at every width. Below 480px only the
  Japanese shows; the English stays for screen readers.
- The 辞書 Dictionary tab is a Japanese-Japanese dictionary written, as far
  as it can be, in words the learner already knows:
  - **Writing:** the Talk model (Settings → Conversation partner; Claude,
    or Ollama) writes a 国語辞典-style entry: up to 3 senses, short
    plain-form definitions, an example each, an English gloss behind a
    toggle. The system prompt lists up to 3,000 learned words, newest first,
    and is a cache point of its own, so each lookup reads it from cache.
  - **Checking:** definitions come back as token lists (surface, reading,
    dictionary form), so the app checks each kanji word against the learned
    set itself. Kana-only words count as grammar. If under 90% of the
    definitions' kanji words are known, the model gets one rewrite request
    naming the unknown ones; the draft shows meanwhile, and the rewrite is
    used only if it's better.
  - **Reading:** unknown words get a dotted underline and their reading
    above; known ones go without ("All readings" shows them). Any kanji word
    can be tapped, or focused and Enter, to look it up, with ◂ back to the
    previous entry. Lesson Meaning pages and review answers link to it.
  - **Cost and cache:** entries are kept in this browser (`wkl_dict`, the
    newest 400; `wkl_dict_recent` for the chips), so a second look-up is
    free. Live, a new word took 4–9 s and about one US cent on Sonnet 5.5.
    Input can be kanji, kana, romaji or English; the model picks the word
    meant.
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
- The Lessons tab teaches the items WaniKani has unlocked
  (`immediately_available_for_lessons`, up to the subscription's level):
  - **Order and size:** WaniKani's, by level, then radicals, kanji and
    vocabulary, then `lesson_position`. The batch is the account's
    `lessons_batch_size` unless "Items per lesson" overrides it.
  - **Pages:** parts (radicals of a kanji, kanji of a word), meaning, reading
    and context, with WaniKani's mnemonics and hints (its `<kanji>`-style
    markup turned into the item colours, everything else escaped), the
    learner's own notes and synonyms, and the example sentences.
  - **Audio:** vocabulary plays WaniKani's own recordings, one voice actor
    throughout; kanji readings, sentences and any failed recording use the
    app's voice. `lessons_autoplay_audio` plays it on arrival.
  - **Quiz:** the Reviews card and engine, moved onto the Lessons tab, with
    voice or typing and misses coming back. It won't start while a review
    session is open, and Reviews won't start during it.
  - **Starting:** each item passed is `PUT /v2/assignments/<id>/start`, as
    WaniKani asks for lesson quizzes instead of reviews. That needs
    `assignments:start` on the token; until then the items wait in
    localStorage (`wkl_ls_outbox`) with a box to paste a token that can.
    A 409/422 (already started elsewhere) is dropped with a note.
- Kanji and vocabulary get a picture, on the lesson's Meaning page and with
  the answer after a miss in Reviews. Radicals don't: their meanings are
  WaniKani's own names. The first of these wins:
  - **The learner's choice**, from "Change" on the picture: a photo, an
    emoji, "No picture", or "Automatic" to go back. Choices live in
    `/opt/wkjp/pics/picks.json` on the VM (nginx `/pics/picks.json`, GET and
    PUT only, 1 MB cap), keyed by subject id, so they follow the learner
    between devices. A save reads the file, changes one entry and writes it
    back, and writes nothing if it can't read it first. Not pruned; not
    backed up beyond the VM.
  - **Japanese Wikipedia:** the lead image of the article titled with the
    word (redirects followed, disambiguation pages skipped), 50 words per
    request, cached per browser in `wkl_pic_auto`. Kana-only words are left
    out because they too often land on a song or a film.
  - **An emoji** whose CLDR name or keyword is the word or its meaning
    (`site/emoji.json`, built by `tools/build-emoji.py` from a pinned CLDR
    release). English matches must start or end the emoji's name, so "big"
    doesn't find 😃 "grinning face with big eyes".
  - The chooser searches Japanese Wikipedia for the word and Wikimedia
    Commons for the meaning, or for whatever is typed. Each photo links to
    its file page for the author and licence.
- The Stats tab's **Practice time** card is a rough log of active time:
  - **Counting:** a 15 s tick adds to today's total for the open tab's
    activity (Lessons, Reviews, Talk, Speak, Dictionary, Practice; not Stats
    or Settings). It counts only while the page is visible, and only if the
    learner has pressed, clicked, scrolled or touched in the last 2 minutes,
    or the mic is open or audio is playing (hands-free Reviews, Live mode).
  - **Storage:** each browser has a random id (`wkl_device`) and its own
    file on the VM, `/opt/wkjp/stats/time-<id>.json` (nginx `/stats/`, GET
    and PUT only for that name pattern, 256 KB cap), saved at most once a
    minute and when the page hides. No browser writes another's file, so
    there's nothing to merge or lose. The Stats tab reads the listing
    (`/stats/`, autoindex JSON) and adds every browser up. Not pruned; a
    browser keeps two years.
  - **Shown:** today, the last 7 days, all time, a streak of days with 5+
    minutes, minutes a day for 14 days (hover or focus a bar for the day by
    activity), and the last 7 days by activity.
- nginx gzips JSON, CSS, JS and SVG (and HTML, always): `index.html` and
  `emoji.json` are a few hundred KB each.
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
  - **"Automatic gain"** is its own switch, on by default, apart from noise
    suppression. With both off, a G733 voice came in about 10 dB quieter
    (-25 to -38 dBFS peaks), and the quiet takes were the misheard ones.
    Saved sessions record `micAGC`.
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
