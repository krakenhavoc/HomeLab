#!/usr/bin/env python3
"""Send the Anki words the learner has started to wkjp, as extra known words.

Runs on the machine with Anki desktop (base-station, Flatpak Anki), from a
systemd user timer (wkjp/tools/systemd/). It reads the collection without
touching it, collects the notes in the deck (default "Kaishi 1.5k") that have
at least one card past "new" (learning, review or relearning), and PUTs them
to wkjp's /anki/known.json, but only when the list changed.

    wkjp-anki-sync [--deck NAME] [--study-deck NAME] [--collection PATH]
                   [--url URL] [--dry-run]

A second, study deck (default "GENKI", the textbook chapters the tutor
assigns; skipped if it doesn't exist) is read too: every note in it that
isn't mature yet (some card under 21 days' interval, new ones included,
suspended ones not) is a word the learner is working on, which wkjp works
into Talk, stories and drills; mature ones join the known words.

Anki holds its collection with an exclusive lock while it's open, so the
script first tries SQLite's backup API (a consistent snapshot) and, if the
file is locked, copies collection.anki2 and its -wal file and reads the copy.

Output: {"v":1, "deck", "at", "total", "started", "words":[{"c","r","m"}],
"study": {"deck", "total", "mature", "working":[{"c","r","m"}]}} with each
note's Word, Word Reading (or Reading) and Word Meaning (or Meaning), HTML
stripped; words newest studied first, working words started first.
"""
import argparse
import glob
import hashlib
import html
import json
import os
import re
import shutil
import sqlite3
import sys
import tempfile
import time
import urllib.request

FLATPAK = os.path.expanduser("~/.var/app/net.ankiweb.Anki/data/Anki2")
NATIVE = os.path.expanduser("~/.local/share/Anki2")
STATE = os.path.expanduser("~/.cache/wkjp-anki-sync/last.sha256")


def find_collection():
    for root in (FLATPAK, NATIVE):
        hits = sorted(glob.glob(os.path.join(root, "*", "collection.anki2")))
        if hits:
            return hits[0]
    sys.exit("no Anki collection found; pass --collection")


def snapshot(path, tmp):
    """A readable copy of the collection, consistent if Anki isn't writing."""
    dst = os.path.join(tmp, "collection.anki2")
    try:
        src = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=2)
        out = sqlite3.connect(dst)
        src.backup(out)
        src.close()
        out.close()
        return dst
    except sqlite3.OperationalError:
        pass  # locked by Anki: copy the files instead
    shutil.copy2(path, dst)
    if os.path.exists(path + "-wal"):
        shutil.copy2(path + "-wal", dst + "-wal")
    return dst


def clean(s):
    s = re.sub(r"\[sound:[^\]]*\]", "", s or "")
    s = re.sub(r"<[^>]+>", "", s)
    return html.unescape(s).strip()


MATURE = 21  # days: Anki's own line for a mature card


def open_db(db_path):
    db = sqlite3.connect(db_path)
    # Anki's own collation, needed by some indexes
    db.create_collation(
        "unicase", lambda a, b: (a.lower() > b.lower()) - (a.lower() < b.lower())
    )
    return db


def deck_ids(db, deck):
    return [
        i
        for i, n in db.execute("select id, name from decks")
        if n.replace("\x1f", "::") == deck
        or n.replace("\x1f", "::").startswith(deck + "::")
    ]


def field_ords(db, mid, cache):
    """Where a note type keeps the word, its reading and its meaning."""
    if mid not in cache:
        names = {
            name: ord_
            for ord_, name in db.execute(
                "select ord, name from fields where ntid=?", (mid,)
            )
        }
        cache[mid] = (
            names.get("Word"),
            names.get("Word Reading", names.get("Reading")),
            names.get("Word Meaning", names.get("Meaning")),
        )
    return cache[mid]


def word_of(flds, ords):
    fw, fr, fm = ords
    if fw is None:
        return None
    v = flds.split("\x1f")
    c = clean(v[fw])
    if not c:
        return None
    return {
        "c": c,
        "r": clean(v[fr]) if fr is not None else "",
        "m": clean(v[fm]) if fm is not None else "",
    }


def read_study(db_path, deck):
    """(total, mature words, working words), or None without the deck."""
    db = open_db(db_path)
    ids = deck_ids(db, deck)
    if not ids:
        db.close()
        return None
    q = ",".join("?" * len(ids))
    rows = db.execute(
        f"""select n.id, n.mid, n.flds, min(c.ivl), max(c.type), max(c.mod)
            from cards c join notes n on n.id = c.nid
            where c.did in ({q}) and c.queue >= 0 group by n.id""",
        ids,
    ).fetchall()
    cache, mature, started, new, seen = {}, [], [], [], set()
    for nid, mid, flds, ivl, typ, mod in rows:
        w = word_of(flds, field_ords(db, mid, cache))
        if not w or w["c"] in seen:
            continue
        seen.add(w["c"])
        if typ == 2 and ivl >= MATURE:
            mature.append(w)
        elif typ > 0:
            started.append((mod, w))
        else:
            new.append((nid, w))
    db.close()
    working = [w for _, w in sorted(started, key=lambda x: -x[0])] + [
        w for _, w in sorted(new)
    ]
    return len(rows), mature, working


def read_words(db_path, deck):
    db = sqlite3.connect(db_path)
    # Anki's own collation, needed by some indexes
    db.create_collation(
        "unicase", lambda a, b: (a.lower() > b.lower()) - (a.lower() < b.lower())
    )
    decks = [
        (i, n.replace("\x1f", "::"))
        for i, n in db.execute("select id, name from decks")
    ]
    ids = [i for i, n in decks if n == deck or n.startswith(deck + "::")]
    if not ids:
        sys.exit(f"no deck named {deck!r}; decks: {[n for _, n in decks]}")
    q = ",".join("?" * len(ids))
    total = db.execute(
        f"select count(distinct nid) from cards where did in ({q})", ids
    ).fetchone()[0]
    rows = db.execute(
        f"""select n.mid, n.flds, max(c.mod) from cards c join notes n on n.id = c.nid
            where c.did in ({q}) and c.type > 0 group by n.id order by max(c.mod) desc""",
        ids,
    ).fetchall()
    fields = {}
    words, seen = [], set()
    for mid, flds, _ in rows:
        if mid not in fields:
            names = {
                name: ord_
                for ord_, name in db.execute(
                    "select ord, name from fields where ntid=?", (mid,)
                )
            }
            fields[mid] = (
                names.get("Word"),
                names.get("Word Reading"),
                names.get("Word Meaning"),
            )
        fw, fr, fm = fields[mid]
        if fw is None:
            continue
        v = flds.split("\x1f")
        c = clean(v[fw])
        if not c or c in seen:
            continue
        seen.add(c)
        words.append(
            {
                "c": c,
                "r": clean(v[fr]) if fr is not None else "",
                "m": clean(v[fm]) if fm is not None else "",
            }
        )
    db.close()
    return total, words


def main():
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--deck", default="Kaishi 1.5k")
    ap.add_argument(
        "--study-deck",
        default="GENKI",
        help="the textbook deck whose unfinished words wkjp should practise ('' for none)",
    )
    ap.add_argument("--collection")
    ap.add_argument("--url", default="https://wkjp.labxp.io/anki/known.json")
    ap.add_argument(
        "--dry-run", action="store_true", help="print the summary, send nothing"
    )
    a = ap.parse_args()
    path = a.collection or find_collection()
    with tempfile.TemporaryDirectory(prefix="wkjp-anki-") as tmp:
        snap = snapshot(path, tmp)
        total, words = read_words(snap, a.deck)
        study = read_study(snap, a.study_deck) if a.study_deck else None
    doc = {
        "v": 1,
        "deck": a.deck,
        "total": total,
        "started": len(words),
        "words": words,
    }
    if study:
        s_total, mature, working = study
        have = {w["c"] for w in words}
        # mature study words are known words too
        doc["words"] = words + [w for w in mature if w["c"] not in have]
        doc["study"] = {
            "deck": a.study_deck,
            "total": s_total,
            "mature": len(mature),
            "working": working,
        }
    digest = hashlib.sha256(
        json.dumps(doc, ensure_ascii=False, sort_keys=True).encode()
    ).hexdigest()
    print(f"{a.deck}: {len(words)} of {total} started")
    if study:
        print(
            f"{a.study_deck}: {len(study[2])} working on, {len(study[1])} mature, of {study[0]}"
        )
    if a.dry_run:
        print(json.dumps(words[:5], ensure_ascii=False))
        return
    try:
        with open(STATE) as f:
            if f.read().strip() == digest:
                print("unchanged; nothing sent")
                return
    except FileNotFoundError:
        pass
    doc["at"] = time.strftime("%Y-%m-%dT%H:%M:%S%z")
    req = urllib.request.Request(
        a.url,
        data=json.dumps(doc, ensure_ascii=False).encode(),
        method="PUT",
        headers={"Content-Type": "application/json", "User-Agent": "wkjp-anki-sync/1"},
    )
    with urllib.request.urlopen(req, timeout=30) as r:
        print(f"sent: HTTP {r.status}")
    os.makedirs(os.path.dirname(STATE), exist_ok=True)
    with open(STATE, "w") as f:
        f.write(digest)


if __name__ == "__main__":
    main()
