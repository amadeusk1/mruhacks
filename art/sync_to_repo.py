#!/usr/bin/env python3
"""Sync the vault's art pack and notes into the Godot game repo (same layout as earlier snapshots).
  python3 art/sync_to_repo.py [--repo PATH] [--dry-run]
Models/, Renders/, art/ are mirrored (deleting files removed from the vault) but Godot's .import/.uid
metadata is kept, and orphaned .import files are removed. Notes (root, Art Docs/, Engine Specs/) go to
docs/ with Obsidian links converted to relative Markdown links; Images/ goes to docs/concepts/.
Repo-only docs (README, PRODUCTION_DIRECTION, ...) are left alone. Writes docs/ASSET_SNAPSHOT.json.
Does not commit or push."""
import argparse, hashlib, json, os, re, shutil, subprocess, urllib.parse, datetime

VAULT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DEFAULT_REPO = os.path.expanduser("~/Documents/Codex/2026-10-23/make-a-new-obsidian-vault-on/mruhacks")
NOTE_DIRS = ["", "Art Docs", "Engine Specs"]
GODOT_META = ["*.import", "*.uid"]

ap = argparse.ArgumentParser()
ap.add_argument("--repo", default=DEFAULT_REPO)
ap.add_argument("--dry-run", action="store_true")
a = ap.parse_args()
REPO = a.repo


def rsync(src, dst, excludes=()):
    cmd = ["rsync", "-a", "--delete"] + [f"--filter=P {m}" for m in GODOT_META] + \
          [f"--exclude={e}" for e in excludes] + (["-n", "-i"] if a.dry_run else []) + [src.rstrip("/") + "/", dst]
    os.makedirs(dst, exist_ok=True)
    out = subprocess.run(cmd, capture_output=True, text=True, check=True).stdout
    if a.dry_run:
        print(out[:3000])


def drop_orphan_meta(root):
    n = 0
    for d, _, fs in os.walk(root):
        for f in fs:
            if f.endswith((".import", ".uid")):
                src = os.path.join(d, f.rsplit(".", 1)[0])
                if not os.path.exists(src):
                    n += 1
                    if not a.dry_run:
                        os.remove(os.path.join(d, f))
    return n


# --- 1. asset folders --------------------------------------------------------
rsync(os.path.join(VAULT, "Models"), os.path.join(REPO, "Models"), [".DS_Store", "*.blend1"])
rsync(os.path.join(VAULT, "Renders"), os.path.join(REPO, "Renders"), [".DS_Store"])
rsync(os.path.join(VAULT, "art"), os.path.join(REPO, "art"), ["_wip/", "__pycache__/", ".DS_Store", "*.blend1"])
orphans = sum(drop_orphan_meta(os.path.join(REPO, d)) for d in ("Models", "Renders", "art"))

# --- 2. concept images ---------------------------------------------------------
img_src, img_dst = os.path.join(VAULT, "Images"), os.path.join(REPO, "docs", "concepts")
os.makedirs(img_dst, exist_ok=True)
for f in os.listdir(img_src):
    if f.startswith("."):
        continue
    s, d = os.path.join(img_src, f), os.path.join(img_dst, f)
    if not a.dry_run and (not os.path.exists(d) or os.path.getmtime(d) < os.path.getmtime(s) or os.path.getsize(d) != os.path.getsize(s)):
        shutil.copy2(s, d)

# --- 3. notes with link conversion -----------------------------------------------
notes = {}  # note name -> path relative to docs/
for nd in NOTE_DIRS:
    d = os.path.join(VAULT, nd)
    for f in sorted(os.listdir(d)):
        if f.endswith(".md"):
            notes[f[:-3]] = os.path.join(nd, f) if nd else f


def rel(target, from_dir):
    return urllib.parse.quote(os.path.relpath(target, from_dir or ".").replace(os.sep, "/"))


def convert(text, note_dir):
    def embed(m):
        tgt = m.group(1).split("|")[0].strip()
        name = os.path.splitext(os.path.basename(tgt))[0]
        if tgt.startswith("Images/"):
            path = os.path.join("concepts", tgt[len("Images/"):])
        else:  # Renders/..., Models/... live beside docs/
            path = os.path.join("..", tgt)
        return f"![{name}]({rel(path, note_dir)})"

    def link(m):
        body = m.group(1).replace("\\|", "|")
        tgt, _, alias = body.partition("|")
        tgt = tgt.strip()
        heading = ""
        if "#" in tgt:
            tgt, heading = tgt.split("#", 1)
            heading = "#" + re.sub(r"[^a-z0-9 -]", "", heading.lower()).replace(" ", "-")
        label = alias.strip() or (os.path.basename(tgt) if tgt else heading.lstrip("#"))
        if not tgt:
            return f"[{label}]({heading})"
        if tgt in notes:
            path = notes[tgt]
        elif tgt.startswith(("Models/", "Renders/", "Images/")):
            path = os.path.join("concepts", tgt[7:]) if tgt.startswith("Images/") else os.path.join("..", tgt)
        else:
            return label  # unresolved: plain text rather than a dead link
        return f"[{label}]({rel(path, note_dir)}{heading})"

    text = re.sub(r"!\[\[([^\]]+)\]\]", embed, text)
    return re.sub(r"\[\[([^\]]+)\]\]", link, text)


written = 0
for name, relpath in notes.items():
    note_dir = os.path.dirname(relpath)
    src = os.path.join(VAULT, relpath)
    dst = os.path.join(REPO, "docs", relpath)
    out = convert(open(src, encoding="utf-8").read(), note_dir)
    if not a.dry_run:
        os.makedirs(os.path.dirname(dst), exist_ok=True)
        if not os.path.exists(dst) or open(dst, encoding="utf-8").read() != out:
            open(dst, "w", encoding="utf-8").write(out)
            written += 1

# --- 4. snapshot manifest -----------------------------------------------------------
def files(root):
    for d, _, fs in os.walk(os.path.join(REPO, root)):
        for f in fs:
            if not f.endswith((".import", ".uid")) and f != ".DS_Store":
                yield os.path.relpath(os.path.join(d, f), REPO)


if not a.dry_run:
    snap = {
        "scope": "Snapshot of the Obsidian vault's art pack (Models, Renders, art) and notes, synced by art/sync_to_repo.py. "
                 "The vault is the live source; file presence is not art approval or gameplay integration.",
        "synced_at": datetime.datetime.now().isoformat(timespec="seconds"),
        "counts": {k: sum(1 for _ in files(k)) for k in ("Models", "Renders", "art", "docs/concepts")},
        "glb_count": sum(1 for p in files("Models") if p.endswith(".glb")),
        "excluded": [".obsidian (personal UI settings)", "art/_wip (intermediate preview renders)",
                     "__pycache__, *.blend1 and OS/editor caches"],
        "sha256": {p: hashlib.sha256(open(os.path.join(REPO, p), "rb").read()).hexdigest()
                   for p in sorted(files("Models")) if p.endswith((".glb", ".blend", ".json"))},
    }
    json.dump(snap, open(os.path.join(REPO, "docs", "ASSET_SNAPSHOT.json"), "w"), indent=2)
    print(f"SYNC glbs={snap['glb_count']} notes_updated={written} orphan_meta_removed={orphans}")
