#!/usr/bin/env python3
"""Is it the speaker or Whisper? Re-run a pronunciation check session's takes
through Whisper with different settings, next to VOICEVOX saying each word.

    wkjp/tools/rec-report.py                # newest session
    wkjp/tools/rec-report.py 20261031-111616

Reads the session from https://wkjp.labxp.io/rec/ (LAN only) and uses the same
/stt/ and /vv/ the app does. Nothing is written back. Settings per take:

    app     language=ja, prompt ひらがな。 (what Reviews uses)
    plain   language=ja, no prompt
    told    language=ja, prompt is the answer itself (can Whisper get there at all?)
    auto    language detection, no prompt
    beam    app settings plus beam_size=5
    reazon  ReazonSpeech on the wkjp VM (/asr/, what Reviews tries first)

VOICEVOX says each word in three voices (the ones Whisper gets right most
often) with silence around it, through the app settings. Verdicts:

    fine      the app setting heard it
    whisper   VOICEVOX fails too in 2+ voices: the word is hard for Whisper
    settings  the app setting missed it but plain/auto/beam/reazon got it
    close     only "told" got it: near enough to steer, not clear on its own
    you       no setting got it while VOICEVOX passes: listen to the take
"""
import json
import re
import sys
import unicodedata
import urllib.parse
import urllib.request
import uuid

BASE = "https://wkjp.labxp.io"
VOICES = (11, 13, 47)  # the three Whisper hears best


def http(url, data=None, headers=None, method=None):
    req = urllib.request.Request(url, data=data, headers=headers or {}, method=method)
    with urllib.request.urlopen(req, timeout=120) as r:
        return r.read()


def stt(audio, name, **fields):
    boundary = uuid.uuid4().hex
    parts = []
    for k, v in fields.items():
        parts.append(
            f'--{boundary}\r\nContent-Disposition: form-data; name="{k}"\r\n\r\n{v}\r\n'.encode()
        )
    parts.append(
        f'--{boundary}\r\nContent-Disposition: form-data; name="file"; filename="{name}"\r\n'
        "Content-Type: application/octet-stream\r\n\r\n".encode() + audio + b"\r\n"
    )
    parts.append(f"--{boundary}--\r\n".encode())
    j = json.loads(
        http(
            f"{BASE}/stt/v1/audio/transcriptions",
            b"".join(parts),
            {"Content-Type": f"multipart/form-data; boundary={boundary}"},
        )
    )
    lp = j.get("language_probabilities") or {}
    return (j.get("text") or "").strip(), round(100 * lp.get("ja", 0))


def asr(audio):
    """ReazonSpeech on the wkjp VM; None if it isn't there"""
    try:
        j = json.loads(
            http(
                f"{BASE}/asr/transcribe",
                audio,
                {"Content-Type": "application/octet-stream"},
            )
        )
        return (j.get("text") or "").strip()
    except Exception:
        return None


def voicevox(text, speaker):
    q = json.loads(
        http(
            f"{BASE}/vv/audio_query?speaker={speaker}&text={urllib.parse.quote(text)}",
            b"",
            method="POST",
        )
    )
    q["prePhonemeLength"], q["postPhonemeLength"] = 0.5, 0.6
    return http(
        f"{BASE}/vv/synthesis?speaker={speaker}",
        json.dumps(q).encode(),
        {"Content-Type": "application/json"},
    )


_kana_cache = {}


def vv_kana(text):
    """VOICEVOX's reading for text Whisper wrote in kanji."""
    if text not in _kana_cache:
        try:
            q = json.loads(
                http(
                    f"{BASE}/vv/audio_query?speaker=3&text={urllib.parse.quote(text)}",
                    b"",
                    method="POST",
                )
            )
            _kana_cache[text] = hira(
                "".join(c for c in q.get("kana", "") if c not in "_'/、？?")
            )
        except Exception:
            _kana_cache[text] = ""
    return _kana_cache[text]


def hira(s):
    return "".join(
        chr(ord(c) - 0x60) if "ァ" <= c <= "ヶ" else c
        for c in unicodedata.normalize("NFKC", s)
    )


def kana_key(s):
    return "".join(c for c in hira(s) if "ぁ" <= c <= "ゖ" or c == "ー")


def vowel(c):
    name = unicodedata.name(c, "")
    return (
        name[-1] if name.startswith("HIRAGANA LETTER") and name[-1] in "AIUEO" else ""
    )


def length_key(s):
    """Whisper drops vowel length (がっこう heard as がっこ); so does this."""
    out, prev = "", ""
    for c in kana_key(s):
        if c == "ー" or (
            c in "あいうえお"
            and (
                vowel(c) == prev
                or (prev == "O" and c == "う")
                or (prev == "E" and c == "い")
            )
        ):
            continue
        out += c
        prev = vowel(c)
    return out.rstrip("っ")


def first_part(t):
    for sep in "、。,.!?！？ \n":
        t = t.replace(sep, "\0")
    return next((p for p in t.split("\0") if p), "")


def judge(text, reading, chars):
    """ok / len (only vowel length differs) / miss, plus the kana it was read as."""
    t = first_part(text)
    if not t:
        return "miss", ""
    k = (
        reading
        if t == chars
        else (vv_kana(t) if any("一" <= c <= "鿿" for c in t) else kana_key(t))
    )
    if kana_key(k) == kana_key(reading):
        return "ok", k
    if length_key(k) and length_key(k) == length_key(reading):
        # VOICEVOX spells 病院 びょおいん: same length, so not a short vowel
        return ("len" if len(kana_key(k)) < len(kana_key(reading)) else "ok"), k
    return "miss", k or t


# Whisper's fill-ins when it can't make out the speech (same list as the app)
STOCK = re.compile(
    "^(ご視聴|ご清聴|チャンネル登録|最後までご視聴|お待ちしております|おやすみなさい"
    "|お疲れ様でした|次回もお楽しみに|字幕|ありがとうございました|ありがとうございます)"
)


def mark(verdict, text):
    shown = first_part(text) or "—"
    stock = " (stock)" if STOCK.match(re.sub(r"[\s。、！？!?.,「」]", "", text)) else ""
    return {"ok": "✓", "len": "≈", "miss": "✗"}[verdict] + shown + stock


def reviews(sid, meta):
    """A Reviews session: what the mic detector saw on each listen, and each answer."""
    cycles, takes = meta.get("cycles", []), meta.get("takes", [])
    print(
        f"reviews session {sid}: {len(cycles)} listens, {len(takes)} answers sent, "
        f"browser noise suppression {'on' if meta.get('micClean') else 'off'}"
    )
    print(f"  {meta.get('ua', '')[:100]}\n")
    by = {}
    for c in cycles:
        by.setdefault(c.get("outcome"), []).append(c)
    for k, cs in sorted(by.items(), key=lambda x: -len(x[1])):
        r = sorted(c.get("peakRatio", 0) for c in cs)
        fl = sorted(c.get("floorDb", -120) for c in cs)
        print(
            f"  {k or '?':9} {len(cs):3}  peak/threshold median {r[len(r) // 2]:.2f}"
            f"  (min {r[0]:.2f}, max {r[-1]:.2f})  floor median {fl[len(fl) // 2]} dB"
        )
    near = [c for c in by.get("silent", []) if c.get("peakRatio", 0) >= 0.5]
    print(
        f"  silent listens where the voice got within 2x of the threshold: {len(near)}\n"
    )
    for t in takes:
        print(
            f"  {t['n']:4} {t['c']} {t['q']:7} want {'/'.join(t.get('want') or [])[:24]:24} "
            f"whisper {str(t.get('whisper'))[:16]:16} reazon {str(t.get('rz'))[:12]:12} "
            f"peak {t.get('peakRatio')}  → {t.get('v', '?')}"
        )


def main():
    global BASE
    args = [a for a in sys.argv[1:] if not a.startswith("--base=")]
    for a in sys.argv[1:]:
        if a.startswith("--base="):
            BASE = a.split("=", 1)[1].rstrip("/")
    if args:
        sid = args[0]
    else:
        sessions = [
            e["name"]
            for e in json.loads(http(f"{BASE}/rec/"))
            if e.get("type") == "directory"
        ]
        if not sessions:
            sys.exit("no sessions saved yet")
        sid = sorted(sessions)[-1]
    meta = json.loads(http(f"{BASE}/rec/{sid}/session.json"))
    if meta.get("kind") == "reviews":
        return reviews(sid, meta)
    print(
        f"session {sid}: {len(meta['takes'])} takes, {len(meta['words'])} words, "
        f"browser noise suppression {'on' if meta.get('micClean') else 'off'}"
    )
    print(f"  {meta.get('ua', '')[:100]}\n")

    configs = {
        "app": {"language": "ja", "prompt": "ひらがな。"},
        "plain": {"language": "ja"},
        "told": None,  # per word
        "auto": {"language": "auto"},
        "beam": {"language": "ja", "prompt": "ひらがな。", "beam_size": "5"},
        "reazon": "asr",
    }
    verdicts, wins = {}, {k: 0 for k in configs}
    for w in meta["words"]:
        takes = [t for t in meta["takes"] if t["r"] == w["r"] and t["c"] == w["c"]]
        if not takes:
            continue
        refs = []
        for v in VOICES:
            try:
                text, ja = stt(
                    voicevox(w["r"], v),
                    "ref.wav",
                    language="ja",
                    prompt="ひらがな。",
                    response_format="verbose_json",
                )
                refs.append((judge(text, w["r"], w["c"])[0], text, ja))
            except Exception as e:
                refs.append(("miss", f"error {e}", 0))
        print(f"{w['c']} {w['r']}  ({w.get('src', '')})")
        print(
            "  VOICEVOX "
            + "  ".join(
                f"v{v} {mark(r[0], r[1])} {r[2]}%" for v, r in zip(VOICES, refs)
            )
        )
        best = []
        for t in takes:
            audio = http(f"{BASE}/rec/{sid}/{t['file']}")
            row, got = [], {}
            for name, fields in configs.items():
                if fields == "asr":
                    text, ja = asr(audio), 0
                    if text is None:
                        got[name] = "miss"
                        row.append(f"{name} n/a")
                        continue
                else:
                    f = dict(fields or {"language": "ja", "prompt": w["r"] + "。"})
                    text, ja = stt(
                        audio, t["file"], response_format="verbose_json", **f
                    )
                v, _ = judge(text, w["r"], w["c"])
                got[name] = v
                row.append(
                    f"{name} {mark(v, text)}" + (f" {ja}%" if name == "app" else "")
                )
            best.append(got)
            if t.get("snr") is not None:
                row.append(f"mic {t['snr']}dB" + (" gated" if t.get("gated") else ""))
            print(f"  take {t['take']}  " + "  ".join(row))
        ref_fail = sum(r[0] == "miss" for r in refs)
        hit = lambda name: any(g[name] in ("ok", "len") for g in best)
        if hit("app"):
            verdict = "fine"
        elif ref_fail >= 2:
            verdict = "whisper"
        elif any(hit(n) for n in ("plain", "auto", "beam", "reazon")):
            verdict = (
                "settings ("
                + ", ".join(n for n in ("plain", "auto", "beam", "reazon") if hit(n))
                + " got it)"
            )
        elif hit("told"):
            verdict = "close"
        else:
            verdict = "you"
        for n in configs:
            wins[n] += hit(n)
        verdicts[w["r"]] = verdict
        print(f"  → {verdict}\n")

    words = len(verdicts)
    print("summary")
    for k in ("fine", "whisper", "settings", "close", "you"):
        n = sum(v.startswith(k) for v in verdicts.values())
        if n:
            print(
                f"  {k:9} {n:2}  "
                + ", ".join(r for r, v in verdicts.items() if v.startswith(k))
            )
    print(
        "  words each setting got: "
        + ", ".join(f"{k} {v}/{words}" for k, v in wins.items())
    )


if __name__ == "__main__":
    main()
