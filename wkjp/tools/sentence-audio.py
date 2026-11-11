#!/usr/bin/env python3
"""Add VOICEVOX sentence audio to Anki cards mined with Yomitan.

Yomitan saves word audio only. This finds notes of the mining note type
(default "Mined") with a Sentence and no sentence clip yet, reads the
sentence with VOICEVOX (the same engine and voice as wkjp), and adds the
clip to the note's Audio field after the word audio, through AnkiConnect,
so the back of the card plays the word, then the sentence. Runs on the
machine with Anki desktop (base-station) from a systemd user timer
(wkjp/tools/systemd/); Anki has to be open, otherwise it waits for next time.

    wkjp-sentence-audio [--model NAME] [--speaker ID] [--anki URL]
                        [--voicevox URL ...] [--limit N] [--dry-run]

No field or template changes: a new field would be a schema change, and
the next AnkiWeb sync would then force a full upload or download. Clips are
named wkjp_sentence_<hash>.wav, which is also how a note is known to be
done. VOICEVOX is tried on
base-station first, then on the wkjp VM. As in wkjp, a pause goes in after
は before いります／いりません (OpenJTalk otherwise reads 入ります).
"""
import argparse
import base64
import hashlib
import html
import json
import re
import sys
import urllib.parse
import urllib.request

FIELD = "Audio"
MARK = "wkjp_sentence_"


class AnkiDown(Exception):
    pass


def anki(url, action, **params):
    req = urllib.request.Request(
        url, json.dumps({"action": action, "version": 6, "params": params}).encode()
    )
    try:
        with urllib.request.urlopen(req, timeout=15) as r:
            out = json.load(r)
    except OSError as e:
        raise AnkiDown(str(e)) from e
    if out.get("error"):
        raise RuntimeError(f"AnkiConnect {action}: {out['error']}")
    return out["result"]


def speakable(field):
    """The sentence as plain text: no markup, sound tags or furigana brackets."""
    s = re.sub(r"\[sound:[^\]]*\]", "", field or "")
    s = re.sub(r"<br\s*/?>", " ", s, flags=re.I)
    s = re.sub(r"<[^>]+>", "", s)
    s = re.sub(r"\[[^\]]*\]", "", s)  # Anki furigana: 漢字[かんじ]
    s = html.unescape(s).replace(" ", " ")
    return re.sub(r"\s+", " ", s).strip()


def say_fix(t):
    return re.sub(r"(?<![にでと])は(?=いりま)", "は、", t)


def synth(bases, text, speaker):
    err = None
    for base in bases:
        try:
            q = urllib.request.Request(
                f"{base}/audio_query?speaker={speaker}&text={urllib.parse.quote(text)}",
                method="POST",
            )
            with urllib.request.urlopen(q, timeout=30) as r:
                query = json.load(r)
            # mono 24 kHz is plenty for speech and keeps the media folder small
            query["outputSamplingRate"] = 24000
            query["outputStereo"] = False
            s = urllib.request.Request(
                f"{base}/synthesis?speaker={speaker}",
                json.dumps(query).encode(),
                {"Content-Type": "application/json"},
            )
            with urllib.request.urlopen(s, timeout=120) as r:
                return r.read()
        except OSError as e:
            err = f"{base}: {e}"
    raise RuntimeError(f"VOICEVOX unavailable ({err})")


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("--model", default="Mined")
    ap.add_argument(
        "--speaker",
        type=int,
        default=2,
        help="VOICEVOX style id (2: 四国めたん ノーマル)",
    )
    ap.add_argument("--anki", default="http://127.0.0.1:8765")
    ap.add_argument(
        "--voicevox",
        action="append",
        help="VOICEVOX base URL, tried in order (default: base-station, then the wkjp VM)",
    )
    ap.add_argument("--limit", type=int, default=50, help="most notes per run")
    ap.add_argument("--dry-run", action="store_true")
    a = ap.parse_args()
    bases = a.voicevox or ["http://127.0.0.1:50121", "https://wkjp.labxp.io/vv"]

    try:
        models = anki(a.anki, "modelNames")
    except AnkiDown:
        print("Anki isn't open (no AnkiConnect); trying again next time")
        return 0
    if a.model not in models:
        print(f"no note type {a.model!r} in Anki; nothing to do")
        return 0
    if FIELD not in anki(a.anki, "modelFieldNames", modelName=a.model):
        print(f"note type {a.model!r} has no {FIELD} field; nothing to do")
        return 0

    ids = anki(
        a.anki, "findNotes", query=f'"note:{a.model}" Sentence:_* -"{FIELD}:*{MARK}*"'
    )
    if not ids:
        return 0
    done = 0
    for n in anki(a.anki, "notesInfo", notes=ids[: a.limit]):
        text = speakable(n["fields"].get("Sentence", {}).get("value", ""))
        if not text:
            continue
        name = (
            MARK
            + hashlib.sha1(f"{a.speaker}|{text}".encode()).hexdigest()[:16]
            + ".wav"
        )
        if a.dry_run:
            print(f"would read: {text}")
            continue
        wav = synth(bases, say_fix(text), a.speaker)
        anki(
            a.anki, "storeMediaFile", filename=name, data=base64.b64encode(wav).decode()
        )
        old = n["fields"][FIELD]["value"].strip()
        anki(
            a.anki,
            "updateNoteFields",
            note={
                "id": n["noteId"],
                "fields": {FIELD: (old + " " if old else "") + f"[sound:{name}]"},
            },
        )
        done += 1
    if done:
        print(f"added sentence audio to {done} note(s)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
