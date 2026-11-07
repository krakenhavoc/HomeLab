#!/usr/bin/env python3
"""Back up wkjp's saved data to an encrypted restic repository.

The wkjp VM is rebuildable from Git; what it can't rebuild is what the app
saved there. This script, on base-station from a nightly systemd user timer
(wkjp/tools/systemd/), copies that data over HTTPS into a staging folder and
takes a restic snapshot of it on the NFS backups share (/mnt/backups):

    /pics/picks.json        picture choices for items
    /stats/time-*.json      practice-time logs, one per browser
    /anki/known.json        started Anki words (also rebuilt by anki-sync)
    /rec/<session>/*        saved review and pronunciation-check recordings

Not backed up: the Anthropic API key (/opt/wkjp/secrets, never served over
HTTP; make a new one in the Console). Recordings the VM pruned after 90 days
stay in older snapshots until those expire.

    wkjp-backup [--url URL] [--repo PATH] [--password-file PATH] [--init]

Retention: 14 daily, 8 weekly, 12 monthly snapshots (restic forget --prune).
Exit 0 on success, 1 on any failure (the systemd unit then shows failed).
Restore: see wkjp/README.md (restic restore latest, then put the files back).
"""
import argparse
import json
import os
import re
import subprocess
import sys
import urllib.error
import urllib.parse
import urllib.request

UA = {"User-Agent": "wkjp-backup/1"}


def get(url):
    with urllib.request.urlopen(
        urllib.request.Request(url, headers=UA), timeout=60
    ) as r:
        return r.read()


def get_or_none(url):
    try:
        return get(url)
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise


def save(path, data):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    tmp = path + ".part"
    with open(tmp, "wb") as f:
        f.write(data)
    os.replace(tmp, path)


def mirror(base, stage):
    """Copy the served data into stage/. Returns a short summary."""
    n = {"files": 0, "new": 0}

    def one(rel, data):
        if data is None:
            return
        save(os.path.join(stage, rel), data)
        n["files"] += 1

    one("pics/picks.json", get_or_none(base + "/pics/picks.json"))
    one("anki/known.json", get_or_none(base + "/anki/known.json"))
    for f in json.loads(get(base + "/stats/")):
        if f.get("type") == "file" and re.fullmatch(
            r"time-[a-f0-9]{16}\.json", f["name"]
        ):
            one("stats/" + f["name"], get(base + "/stats/" + f["name"]))
    # recordings: only files not already staged at the same size
    for d in json.loads(get(base + "/rec/")):
        if d.get("type") != "directory" or not re.fullmatch(r"\d{8}-\d{6}", d["name"]):
            continue
        for f in json.loads(get(f"{base}/rec/{d['name']}/")):
            name = f.get("name", "")
            if f.get("type") != "file" or not re.fullmatch(
                r"(\d{2,4}-\d{1,2}\.(webm|ogg|mp4)|session\.json)", name
            ):
                continue
            path = os.path.join(stage, "rec", d["name"], name)
            n["files"] += 1
            # session.json changes as a session goes on; clips don't
            if (
                name != "session.json"
                and os.path.exists(path)
                and os.path.getsize(path) == f.get("size")
            ):
                continue
            save(path, get(f"{base}/rec/{d['name']}/{urllib.parse.quote(name)}"))
            n["new"] += 1
    return n


def restic(args, repo, pwfile):
    env = dict(os.environ, RESTIC_REPOSITORY=repo, RESTIC_PASSWORD_FILE=pwfile)
    return subprocess.run(["restic", *args], env=env, check=True)


def main():
    home = os.path.expanduser("~")
    ap = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    ap.add_argument("--url", default="https://wkjp.labxp.io")
    ap.add_argument("--repo", default="/mnt/backups/wkjp-restic")
    ap.add_argument(
        "--password-file", default=f"{home}/.config/wkjp-backup/restic-password"
    )
    ap.add_argument("--stage", default=f"{home}/.cache/wkjp-backup/data")
    ap.add_argument(
        "--init", action="store_true", help="create the restic repository first"
    )
    a = ap.parse_args()
    if not os.path.exists(a.password_file):
        sys.exit(f"no restic password at {a.password_file}; see wkjp/README.md")
    if a.init:
        restic(["init"], a.repo, a.password_file)
    s = mirror(a.url.rstrip("/"), a.stage)
    print(f"staged {s['files']} files ({s['new']} new recordings fetched)")
    restic(
        ["backup", "--quiet", "--tag", "wkjp", "--host", "wkjp", a.stage],
        a.repo,
        a.password_file,
    )
    restic(
        [
            "forget",
            "--quiet",
            "--tag",
            "wkjp",
            "--keep-daily",
            "14",
            "--keep-weekly",
            "8",
            "--keep-monthly",
            "12",
            "--prune",
        ],
        a.repo,
        a.password_file,
    )
    print("snapshot taken")


if __name__ == "__main__":
    try:
        main()
    except (subprocess.CalledProcessError, OSError, ValueError) as e:
        sys.exit(f"wkjp-backup failed: {e}")
