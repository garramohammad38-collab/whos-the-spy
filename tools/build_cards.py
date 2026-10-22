#!/usr/bin/env python3
"""Build SpyGame/Resources/cards.json from data/players.tsv and validate it.

TSV columns (tab separated, no header):
    english  arabic  hebrew  tags(comma)  difficulty(1-3)  status(active|retired)

Usage:  python3 tools/build_players.py          (from the project root)
Exit code is non-zero if validation fails.
"""
import json
import re
import sys
import unicodedata
from datetime import date
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "data" / "players.tsv"
WORDS = ROOT / "data" / "words.tsv"
DECKS = {"animals", "countries", "food", "jobs", "things", "arabcelebs", "movies", "cartoons"}
OUT = ROOT / "SpyGame" / "Resources" / "cards.json"

TAGS = {"stars", "legends", "arab", "premier", "laliga", "seriea", "bundesliga", "ligue1", "saudi"}
STATUS = {"active", "retired"}
ARABIC = re.compile(r"[؀-ۿ]")
HEBREW = re.compile(r"[֐-׿]")


def slug(name: str) -> str:
    s = unicodedata.normalize("NFKD", name)
    s = "".join(c for c in s if not unicodedata.combining(c)).lower()
    s = s.replace("ø", "o").replace("ı", "i").replace("ß", "ss").replace("đ", "d")
    return re.sub(r"[^a-z0-9]+", "-", s).strip("-")


def main() -> int:
    errors, players, ids, names = [], [], set(), {"ar": set(), "he": set()}
    for n, line in enumerate(SRC.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip() or line.startswith("#"):
            continue
        f = [x.strip() for x in line.split("\t")]
        if len(f) != 6:
            errors.append(f"line {n}: expected 6 fields, got {len(f)}")
            continue
        en, ar, he, tags, diff, status = f
        # Normalise ASCII apostrophe in Hebrew to the Hebrew geresh.
        he = he.replace("'", "׳")
        tag_list = [t for t in tags.split(",") if t]
        pid = slug(en)
        if not en or not ar or not he:
            errors.append(f"line {n}: empty name")
        if not ARABIC.search(ar):
            errors.append(f"line {n}: arabic name has no Arabic letters: {ar}")
        if not HEBREW.search(he):
            errors.append(f"line {n}: hebrew name has no Hebrew letters: {he}")
        if bad := set(tag_list) - TAGS:
            errors.append(f"line {n}: unknown tags {bad}")
        if not tag_list:
            errors.append(f"line {n}: no tags")
        if diff not in {"1", "2", "3"}:
            errors.append(f"line {n}: difficulty must be 1-3")
        if status not in STATUS:
            errors.append(f"line {n}: bad status {status}")
        if "legends" in tag_list and status != "retired":
            errors.append(f"line {n}: legend must be retired: {en}")
        if pid in ids:
            errors.append(f"line {n}: duplicate player {en}")
        if ar in names["ar"]:
            errors.append(f"line {n}: duplicate arabic name {ar}")
        if he in names["he"]:
            errors.append(f"line {n}: duplicate hebrew name {he}")
        ids.add(pid); names["ar"].add(ar); names["he"].add(he)
        players.append({"id": pid, "en": en, "ar": ar, "tags": sorted(set(tag_list)),
                        "difficulty": int(diff) if diff.isdigit() else 0, "status": status})

    # Party decks (no Hebrew, status "item").
    seen = set()
    for n, line in enumerate(WORDS.read_text(encoding="utf-8").splitlines(), 1):
        if not line.strip() or line.startswith("#"):
            continue
        f = [x.strip() for x in line.split("\t")]
        if len(f) != 4:
            errors.append(f"words line {n}: expected 4 fields, got {len(f)}")
            continue
        deck, diff, en, ar = f
        wid = f"{deck}-{slug(en)}"
        if deck not in DECKS:
            errors.append(f"words line {n}: unknown deck {deck}")
        if diff not in {"1", "2", "3"}:
            errors.append(f"words line {n}: difficulty must be 1-3")
        if not en or not ARABIC.search(ar):
            errors.append(f"words line {n}: bad names {en} / {ar}")
        if wid in seen or (deck, ar) in seen:
            errors.append(f"words line {n}: duplicate {en}")
        seen.add(wid); seen.add((deck, ar))
        players.append({"id": wid, "en": en, "ar": ar, "tags": [deck],
                        "difficulty": int(diff) if diff.isdigit() else 0, "status": "item"})

    if errors:
        print("\n".join(errors))
        print(f"FAILED: {len(errors)} problem(s)")
        return 1

    db = {"version": 1, "updated": date.today().isoformat(), "players": players}
    OUT.parent.mkdir(parents=True, exist_ok=True)
    OUT.write_text(json.dumps(db, ensure_ascii=False, indent=1), encoding="utf-8")

    counts = {t: sum(t in p["tags"] for p in players) for t in sorted(TAGS | DECKS)}
    diffs = {d: sum(p["difficulty"] == d for p in players) for d in (1, 2, 3)}
    print(f"OK: {len(players)} players -> {OUT.relative_to(ROOT)}")
    print("per tag:", counts)
    print("per difficulty:", diffs)
    return 0


if __name__ == "__main__":
    sys.exit(main())
