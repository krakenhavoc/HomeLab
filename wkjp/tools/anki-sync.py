#!/usr/bin/env python3
"""Send the Anki words the learner has started to wkjp, as extra known words.

Runs on the machine with Anki desktop (base-station, Flatpak Anki), from a
systemd user timer (wkjp/tools/systemd/). It reads the collection without
touching it and PUTs wkjp's /anki/known.json, but only when it changed:

  - known words: every note, in any deck, with a Word field and at least one
    card past "new" (learning, review or relearning). The main deck
    (default "Kaishi 1.5k") comes first and gives the progress shown on
    Today ("254 of 1501 started").
  - words in progress: the study decks (default "GENKI,Post-1.5k": the
    textbook chapters the tutor assigns and the words mined with Yomitan;
    missing ones are skipped). Every note in them that's been started but
    isn't mature yet (some card under 21 days' interval; new and suspended
    ones not) is one wkjp works into Talk, stories and drills; a new card
    joins once it's been started, and mature ones are known.

    wkjp-anki-sync [--deck NAME] [--study-deck NAMES] [--collection PATH]
                   [--url URL] [--dry-run]

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


BACKUP_SECONDS = 20


def snapshot(path, tmp):
    """A readable copy of the collection, consistent if Anki isn't writing."""
    dst = os.path.join(tmp, "collection.anki2")
    # The backup API retries for as long as Anki holds a lock (it did after a
    # burst of AnkiConnect writes, and the sync hung for 11 minutes). Its
    # progress callback runs on every retry, so give up there after a while.
    deadline = time.monotonic() + BACKUP_SECONDS

    def progress(status, remaining, total):
        if time.monotonic() > deadline:
            raise TimeoutError("collection stayed locked")

    src = out = None
    try:
        src = sqlite3.connect(f"file:{path}?mode=ro", uri=True, timeout=2)
        out = sqlite3.connect(dst)
        src.backup(out, progress=progress)
        return dst
    except (sqlite3.OperationalError, TimeoutError):
        pass  # locked by Anki: copy the files instead
    finally:
        for c in (src, out):
            if c is not None:
                c.close()
    if os.path.exists(dst):
        os.remove(dst)
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
    cache, mature, started, seen = {}, [], [], set()
    for nid, mid, flds, ivl, typ, mod in rows:
        w = word_of(flds, field_ords(db, mid, cache))
        if not w or w["c"] in seen:
            continue
        seen.add(w["c"])
        if typ == 2 and ivl >= MATURE:
            mature.append(w)
        elif typ > 0:
            started.append((mod, w))
        # not started yet: neither known nor in progress until it's been seen
    db.close()
    working = [w for _, w in sorted(started, key=lambda x: -x[0])]
    return len(rows), mature, working


def read_started(db_path):
    """Every started note with a Word field, in any deck, newest studied first."""
    db = open_db(db_path)
    rows = db.execute(
        """select n.mid, n.flds, max(c.mod) from cards c join notes n on n.id = c.nid
           where c.type > 0 group by n.id order by max(c.mod) desc"""
    ).fetchall()
    cache, words, seen = {}, [], set()
    for mid, flds, _ in rows:
        w = word_of(flds, field_ords(db, mid, cache))
        if w and w["c"] not in seen:
            seen.add(w["c"])
            words.append(w)
    db.close()
    return words


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
        default="GENKI,Post-1.5k",
        help="comma-separated decks whose unfinished words wkjp should practise ('' for none)",
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
        everywhere = read_started(snap)
        names = [d.strip() for d in (a.study_deck or "").split(",") if d.strip()]
        found = [(d, read_study(snap, d)) for d in names]
    found = [(d, r) for d, r in found if r]
    study = None
    if found:
        mature, working, seen = [], [], set()
        for _, (_, m, w) in found:
            mature += m
            for x in w:
                if x["c"] not in seen:
                    seen.add(x["c"])
                    working.append(x)
        study = (sum(r[0] for _, r in found), mature, working)
    # the main deck's words first, then what's been started anywhere else
    have = {w["c"] for w in words}
    known = words + [
        w for w in everywhere if w["c"] not in have and not have.add(w["c"])
    ]
    doc = {
        "v": 1,
        "deck": a.deck,
        "total": total,
        "started": len(words),
        "words": known,
    }
    if study:
        s_total, mature, working = study
        # mature study words are known words too
        doc["words"] = known + [
            w for w in mature if w["c"] not in have and not have.add(w["c"])
        ]
        doc["study"] = {
            "deck": ", ".join(d for d, _ in found),
            "total": s_total,
            "mature": len(mature),
            "working": working,
        }
    digest = hashlib.sha256(
        json.dumps(doc, ensure_ascii=False, sort_keys=True).encode()
    ).hexdigest()
    print(
        f"{a.deck}: {len(words)} of {total} started; {len(doc['words'])} known words in all"
    )
    if study:
        print(
            f"{doc['study']['deck']}: {len(study[2])} working on, {len(study[1])} mature, of {study[0]}"
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
