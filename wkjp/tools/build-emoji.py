#!/usr/bin/env python3
"""Build wkjp/site/emoji.json from Unicode CLDR's emoji names and keywords.

Items without a photo fall back to an emoji found by their Japanese word or
English meaning. CLDR names every emoji (its "tts" name) and lists keywords,
in English and Japanese. The app looks a word up as a name first, then as a
keyword:

- Japanese: a keyword's emoji whose own name contains it come first, shortest
  name first, so 犬 finds 🐶 (犬の顔) rather than 🦴 (骨); the rest follow.
- English: only emoji whose name starts or ends with the word, so "leaf"
  finds 🍂 fallen leaf and "cold" 🥶 cold face, but "big" doesn't find 😃
  grinning face with big eyes. English keywords are too loose to use alone.

    wkjp/tools/build-emoji.py [CLDR tag]      # default below; writes the file

Output: {"v": tag, "n": {name: emoji}, "k": {keyword: [c, emoji, ...]}},
where the first c emoji are the close matches. English is lower-cased;
Japanese and English keys can't collide, so they share the maps.
"""
import json
import pathlib
import sys
import urllib.request

TAG = sys.argv[1] if len(sys.argv) > 1 else "49.0.0"
URL = (
    "https://raw.githubusercontent.com/unicode-org/cldr-json/{tag}/cldr-json/"
    "cldr-annotations-full/annotations/{lang}/annotations.json"
)
OUT = pathlib.Path(__file__).resolve().parent.parent / "site" / "emoji.json"
MAX_PER_KEYWORD = 4


def fetch(lang):
    with urllib.request.urlopen(URL.format(tag=TAG, lang=lang), timeout=60) as r:
        return json.load(r)["annotations"]["annotations"]


def close(lang, k, name):
    """Is this emoji's name a close match for the keyword?"""
    if lang == "ja":
        return k in name
    return name.startswith(k + " ") or name.endswith(" " + k)


def main():
    names, keywords = {}, {}
    for lang in ("ja", "en"):
        ann = fetch(lang)
        norm = (lambda s: s.strip().lower()) if lang == "en" else (lambda s: s.strip())
        for emoji, a in ann.items():
            # keycaps, tags and the like have no tts; skip anything nameless
            tts = a.get("tts")
            if not tts:
                continue
            name = norm(tts[0])
            names.setdefault(name, emoji)
            for k in a.get("default", []):
                k = norm(k)
                if not k or k == name:
                    continue
                near = close(lang, k, name)
                if lang == "en" and not near:
                    continue
                keywords.setdefault(k, []).append((not near, len(name), emoji))
    k_out = {}
    for k, v in keywords.items():
        top = sorted(v)[:MAX_PER_KEYWORD]
        k_out[k] = [sum(1 for far, _, _ in top if not far)] + [e for _, _, e in top]
    OUT.write_text(
        json.dumps(
            {"v": TAG, "n": names, "k": k_out},
            ensure_ascii=False,
            separators=(",", ":"),
            sort_keys=True,
        )
        + "\n",
        encoding="utf-8",
    )
    print(
        f"{OUT}: {len(names)} names, {len(k_out)} keywords, {OUT.stat().st_size} bytes"
    )


if __name__ == "__main__":
    main()
